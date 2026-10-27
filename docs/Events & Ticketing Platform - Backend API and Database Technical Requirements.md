# Come2Kids (Come to Kids) — Backend API and Database Technical Requirements

*Student internship project · Version 1.1 (draft)*

## 1. Project Overview

Come2Kids (Come to Kids) is a web platform for publishing events and selling tickets to them. Organizations (event organizers) publish events; visitors browse them; registered users buy tickets, receive them by email as PDF files, and leave feedback about events and organizations. Platform moderators approve new organizations and event publications to protect the resource from spam and inappropriate content.

This document defines the requirements for the **backend REST API** and the **relational database**. The frontend (React + TypeScript + Tailwind CSS) is developed separately, but the API must be designed so that any client (web or mobile) can use it.

### 1.1 Goals

- Provide a secure, documented REST API covering all user roles and use cases below.
- Design a normalized relational database that supports these use cases with data integrity.
- Give interns practical experience with authentication, role-based access control, state machines, email delivery, file generation, and database design.

### 1.2 Technology Stack

The stack is fixed for all teams. Items marked "suggested" are recommended libraries the team may replace.

| Area | Technology |
| --- | --- |
| Project repository | [UA-5382-Ruby/come2kids](https://github.com/UA-5382-Ruby/come2kids) |
| Backend framework | Ruby on Rails (API mode) |
| ORM | ActiveRecord with migrations |
| Primary database | PostgreSQL |
| Activity logs | MongoDB (suggested ODM: Mongoid) |
| Authentication | JWT (access + refresh tokens) |
| Payments | monobank Acquiring API, test environment only, one shared test token ([testing guide](https://monobank.ua/api-docs/acquiring/dev/test/docs--testing)) |
| Frontend | React + TypeScript + Tailwind CSS |
| Localization | Ukrainian (default) and English: Rails I18n on the backend, translation tables for content |
| Backend testing | RSpec |
| JavaScript testing | Jest |
| Code quality | Rubocop |
| Email and background jobs | ActionMailer with SMTP or an email provider; Active Job with a queue adapter (suggested: Sidekiq) and a scheduler for recurring jobs |
| PDF and QR generation | Suggested: Prawn (PDF) and rqrcode (QR code) |
| File storage | Active Storage (images: banners, avatars, logos) |
| API documentation | OpenAPI/Swagger (suggested: rswag) |

## 2. Roles and Permissions

| Role | Description |
| --- | --- |
| **Guest** | Unauthenticated visitor. |
| **User** | Authenticated, email-verified account. |
| **Organization Owner** | A user who owns an approved organization. One owner per organization. |
| **Organization Manager** | A user assigned by the owner to help manage the organization's events. |
| **Resource Moderator** | Platform staff who approve organizations and events. |

Owner, Manager and Moderator are also Users and keep all User permissions (buying tickets, reviews, profile). A single user may be a manager in several organizations.

### 2.1 Permission Matrix

| Capability | Guest | User | Org Manager | Org Owner | Moderator |
| --- | :-: | :-: | :-: | :-: | :-: |
| View list of published events | ✔ | ✔ | ✔ | ✔ | ✔ |
| View event details | ✔ | ✔ | ✔ | ✔ | ✔ |
| Register / log in | ✔ | — | — | — | — |
| Buy tickets (paid and free events) | — | ✔ | ✔ | ✔ | ✔ |
| View purchased tickets, download PDF | — | ✔ | ✔ | ✔ | ✔ |
| Subscribe to events and organizations | — | ✔ | ✔ | ✔ | ✔ |
| Review an event attended | — | ✔ | ✔ | ✔ | ✔ |
| Review an organization (after attending its event) | — | ✔ | ✔ | ✔ | ✔ |
| View / edit own profile (except email) | — | ✔ | ✔ | ✔ | ✔ |
| Create / update / delete events of own organization (edits of published events go to re-moderation) | — | — | ✔ | ✔ | — |
| Check in tickets by scanning QR codes | — | — | ✔ | ✔ | — |
| Answer questions (comments) on events / organization | — | — | ✔ | ✔ | — |
| Update organization information, transfer ownership | — | — | — | ✔ | — |
| Add / remove organization managers | — | — | — | ✔ | — |
| Approve / reject new organizations | — | — | — | — | ✔ |
| Approve / reject event publication and re-moderation | — | — | — | — | ✔ |
| Block / unblock users and organizations; decide on appeals | — | — | — | — | ✔ |
| Answer questions about the platform itself | — | — | — | — | ✔ |

Permission checks must be enforced on the server for every request. Ownership checks are required (e.g., a manager of organization A must not edit events of organization B).

## 3. Functional Requirements

### 3.1 Authentication and Account Management

- **FR-AUTH-1** A guest can register with email, password, first name and last name.
- **FR-AUTH-2** After registration the account is *unverified*. The system sends a confirmation email with a single-use, time-limited token (e.g., 24 hours). The user cannot log in or buy tickets until the email is confirmed.
- **FR-AUTH-3** The user can request resending of the confirmation email (rate-limited).
- **FR-AUTH-4** Login returns a short-lived access token and a long-lived, revocable refresh token.
- **FR-AUTH-5** Password reset via emailed token.
- **FR-AUTH-6** Passwords are stored only as salted hashes (bcrypt, Argon2 or PBKDF2). Minimum 8 characters, at least one letter and one digit.
- **FR-AUTH-7** The user can view and edit their profile (first name, last name, phone, date of birth, avatar, city, etc.). **The email address cannot be changed.**

### 3.2 Events (public part)

- **FR-EVT-1** Guests and users can list events with status `Published`. Events in other statuses are never returned by public endpoints.
- **FR-EVT-2** The list supports pagination, sorting (date, price, popularity) and filtering (date range, category, city/online, price range, organization, free-text search by title).
- **FR-EVT-3** Event details include: title, description, banner and gallery images, category, start/end date and time, time zone, location (address or online link), organization (name, logo), ticket types with price and availability, average rating, and reviews.
- **FR-EVT-4** Past events remain visible (marked as finished) so reviews can be read, but tickets cannot be bought for them.

### 3.3 Tickets

- **FR-TKT-1** An authenticated, verified user can order one or more tickets of a chosen ticket type for a published event that has not started yet and whose sale window is open. Both paid and free events are supported.
- **FR-TKT-2** Order creation must be transactional: the availability check, the order and the reservation of the requested quantity happen atomically (row-level locking or optimistic concurrency). Overselling is not allowed, including under concurrent requests. Reservations of unpaid orders are released when the payment fails or expires (see Section 3.10).
- **FR-TKT-3** Paid tickets are paid through monobank acquiring (Section 3.10); tickets are issued only after the payment status becomes `success`. Free tickets (price 0) skip payment: the order becomes `Paid` immediately and the tickets are issued at once.
- **FR-TKT-4** After a successful payment (or a free order) the system sends an email containing the order information (event, date, location, ticket types, quantities, total price) and the PDF ticket(s) as attachment.
- **FR-TKT-5** Every ticket has a unique code and a **QR code**. The QR code encodes an opaque, unguessable token that identifies the ticket (no personal data in it) and is used for entrance check-in (Section 3.14). It is generated on the server and embedded in the PDF ticket and exposed by the API.
- **FR-TKT-6** A user can list their purchased tickets, view the details of each (including the QR code), and download the ticket as PDF at any time. The PDF contains the event title, date and time, location, ticket type, holder name, ticket code and the QR code, in the user's language.
- **FR-TKT-7** Each ticket type has a fixed quantity defined by the organizer. There is no limit on the number of tickets one user can buy for an event, except the number still available. When the tickets are sold out, the API returns a clear error code.
- **FR-TKT-8** Refunds and cancellation of purchased tickets by the buyer are not supported in this version.

### 3.4 Reviews

- **FR-REV-1** A user can leave **one** review per event, only if they hold a ticket for that event and the event has ended.
- **FR-REV-2** A user can leave **one** review per organization, only if they attended at least one event of that organization.
- **FR-REV-3** A review contains a rating (1–5) and an optional text. The author can edit or delete their own review.
- **FR-REV-4** Event and organization average ratings are exposed in the API (computed or cached and kept consistent).

### 3.5 Questions and Comments (Q&A)

- **FR-QA-1** A user can ask a question on an event or on an organization page.
- **FR-QA-2** Organization owner and managers can answer questions related to their organization or its events.
- **FR-QA-3** Moderators can answer questions related to the platform (support questions).
- **FR-QA-4** A question has an author, text, date, target (event / organization / platform) and zero or more answers. Questions and answers are publicly visible.
- **FR-QA-5** Authors can delete their own questions; owners/managers/moderators can hide inappropriate content.

### 3.6 Organizations

- **FR-ORG-1** A verified user can submit a request to create an organization (name, description, logo, contact email/phone, website, address). The submitter becomes its Owner after approval.
- **FR-ORG-2** A new organization has status `PendingApproval` until a moderator approves or rejects it (with a reason). Unapproved organizations cannot publish events.
- **FR-ORG-3** The Owner can update organization information.
- **FR-ORG-4** The Owner can add managers (by existing user email) and remove them. Managers cannot manage other managers.
- **FR-ORG-5** The public API exposes an organization page: info, list of published events, rating and reviews, questions and answers.

* **FR-ORG-6** A user can own **only one** organization (unique owner per user). A user can still be a manager in several organizations, but cannot be owner and manager of the same one. Ownership transfer is described in FR-ORG-8.
* **FR-ORG-7** A blocked organization is handled as described in FR-MOD-5.

- **FR-ORG-8** *(planned for a later phase, after the core features)* The Owner can transfer ownership to another verified user who does not already own an organization (typically a current manager). The Owner starts the transfer by the recipient's email; the recipient receives an email and accepts or declines within 7 days. On acceptance the change is atomic: the recipient becomes the owner (and stops being a manager of this organization), and the previous owner becomes a manager, whom the new owner can later remove like any other manager. Only one pending transfer per organization is allowed. The Owner can cancel a pending transfer. Transfers are logged and both parties are notified.

### 3.7 Event Management (Owner and Manager)

- **FR-EM-1** Owner and managers can create, update and delete events of their organization.
- **FR-EM-2** Event creation follows the status workflow in Section 4.
- **FR-EM-3** Editing a `Published` event: any edit of a published event requires re-moderation. The changes are saved as a pending revision and sent to moderation, while the last approved version stays public and ticket sales continue. The changes become public only after a moderator approves the revision; if it is rejected, the public version stays unchanged and the editor receives the reason. Tickets already sold stay valid. When the approved changes affect date, time, location or price, ticket holders and subscribers are notified by email.
- **FR-EM-4** Deleting an event that has sold tickets must not physically remove data: the event is moved to a cancelled status and ticket holders are notified. Events without tickets may be soft-deleted.
- **FR-EM-5** Owner and managers can view the list of their organization's events in all statuses and the list of sold tickets / participants per event.

* **FR-EM-6** An event has one or more ticket types. Each ticket type has a name, a price (0 means free) and a fixed total quantity greater than 0. The quantity cannot be lowered below the number of tickets already sold.
* **FR-EM-7** Event title and description are entered in Ukrainian (required) and optionally in English (see Section 3.15).

- **FR-EM-8** A published event has at most one pending revision at a time. A revision contains all editable data: translated texts, dates, location, images and ticket types. The creator, owner or managers can edit or withdraw a pending revision while it is under review. Ticket quantity cannot be lowered below the number of tickets sold, and prices of tickets already sold do not change.
- **FR-EM-9** When a revision is approved, its data replaces the public version in one transaction, subscribers and ticket holders are notified (FR-SUB-3), and reminder records are cleared if the start time changed. Edits of events in `Draft` or `Rejected` status do not need a revision.

### 3.8 Moderation

- **FR-MOD-1** Moderators see a queue of organizations in `PendingApproval` and events in `UnderReview`.
- **FR-MOD-2** A moderator approves or rejects an item. Rejection requires a reason. The creator is notified by email.
- **FR-MOD-3** All moderation decisions are logged (who, when, decision, reason).

* **FR-MOD-4** Moderators can block and unblock **users**; a reason is required. A blocked user cannot log in, all their refresh tokens are revoked, and they cannot buy tickets, write reviews or ask questions. Moderators cannot block other moderators. A blocked user can appeal (Section 3.16).
* **FR-MOD-5** Moderators can block and unblock **organizations**; a reason is required. A blocked organization and its events are hidden from public lists, its ticket sales are stopped, and its owner and managers cannot create or edit events. Already sold tickets stay valid and are not refunded automatically. The owner can appeal the block (Section 3.16).
* **FR-MOD-6** Pending revisions of published events appear in the moderation queue next to new events and show the old and new values side by side.
* **FR-MOD-7** Every block and unblock is written to the moderation log and the activity log, and the affected user or organization owner is notified by email with the reason.

### 3.9 Notifications (Email)

| Trigger | Recipient | Content |
| --- | --- | --- |
| Registration | New user | Confirmation link |
| Password reset request | User | Reset link |
| Ticket purchase (paid or free) | Buyer | Order summary + PDF ticket(s) |
| Organization approved/rejected | Owner | Decision and reason |
| Event approved/rejected (including re-moderation) | Creator | Decision and reason |
| Event cancelled, or changed after approval | Ticket holders and event subscribers | Details of the change |
| New event published by an organization | Organization subscribers | Event summary and link |
| 24 hours before the event | Event subscribers and ticket holders | Event reminder (Section 3.13) |
| Answer to a question | Question author | Answer text and link |
| User or organization blocked / unblocked | Affected user or organization owner | Decision and reason |
| Event revision approved/rejected | Editor | Decision and reason |
| Ownership transfer requested / accepted / declined | Recipient and current owner | Request link or result |
| Appeal accepted / rejected | Blocked user | Decision and reason |

All emails use the recipient's preferred language (Ukrainian by default).

Emails must be sent asynchronously (background job or queue) so API responses are not blocked, with retries and error logging.

### 3.10 Payments (monobank Acquiring)

Tickets are paid through monobank internet acquiring ([documentation](https://monobank.ua/api-docs/acquiring/methods/ia/post--api--merchant--invoice--create)). The buyer pays on a monobank-hosted page, so the platform never receives or stores card data.

- **FR-PAY-1** The integration is limited to the monobank **test environment** for the whole internship. All teams use one shared test token from [api.monobank.ua](https://api.monobank.ua/). In the test environment any card number, expiry date and CVV are accepted, provided the card number passes the Luhn check; no money is charged. Apple Pay and Google Pay are not shown with a test token. The token is stored only in environment variables or the team secret store, never in the repository.
- **FR-PAY-2** When the user orders paid tickets, the backend creates an order with status `Pending` and calls `POST /api/merchant/invoice/create` (header `X-Token`). The request carries `amount` in minor units (kopecks, integer), `ccy` 980, `redirectUrl`, `webHookUrl`, `validity` (seconds; recommended 900, equal to the ticket reservation time) and `merchantPaymInfo` with the order data. The response returns `invoiceId` and `pageUrl`; the backend stores `invoiceId` in the payment record and returns `pageUrl` to the client, which redirects the buyer.
- **FR-PAY-3** The webhook endpoint receives payment status changes by POST. It must verify the request signature with the monobank public key (see the [webhook verification guide](https://monobank.ua/api-docs/acquiring/dev/webhooks/verify)), respond with 200 quickly, and be idempotent. The webhook URL must be reachable from the internet (for local development use a tunnel) or the status must be polled (FR-PAY-5).
- **FR-PAY-4** monobank does not guarantee the order of webhook delivery: a `success` webhook can arrive before `processing`. The handler compares `modifiedDate` and ignores a webhook older than the stored state.
- **FR-PAY-5** If a webhook is missed, the backend checks the payment with `GET /api/merchant/invoice/status?invoiceId=...`. A background job re-checks payments that stay `Pending` after the redirect, and the client can poll the order status endpoint. Because all teams share one token, calls must handle HTTP 429 (too many requests) with retry and backoff.
- **FR-PAY-6** Payment statuses are mapped to order statuses as shown below. Only `debit` payments are used; `hold` and `verification` are out of scope.
- **FR-PAY-7** A failed payment stores `errCode` and `failureReason` from monobank. The user may retry with a new invoice for the same order while the reservation is valid.
- **FR-PAY-8** Refunds and buyer-side cancellation are not supported, so the monobank cancel endpoint is not used. If an organizer cancels an event, ticket holders are notified by email and money returns are handled outside the platform.
- **FR-PAY-9** Free tickets (price 0) never create a monobank invoice.

| monobank invoice status | Order status | Action |
| --- | --- | --- |
| `created`, `processing` | Pending | Keep the reservation |
| `success` | Paid | Issue tickets, generate QR and PDF, send email |
| `failure` | Failed | Release the reservation, store `errCode` and `failureReason` |
| `expired` | Expired | Release the reservation |
| `reversed` | Refunded | Mark tickets as Cancelled |

### 3.11 Activity Logging

The platform stores a log of user activity for audit and troubleshooting. Activity logs are separate from the technical application log.

- **FR-LOG-1** The following actions are logged: registration, email confirmation, login (successful and failed), logout, token refresh, password reset, profile update, order creation, payment status changes, ticket download, review and question create/edit/delete, organization and event create/update/delete, event status transitions, moderation decisions, manager add/remove.
- **FR-LOG-2** Each entry contains: UTC timestamp, user id (empty for guests), role, action name (for example `user.login`), target entity type and id, result (success or failure), IP address, user agent, request id, and a metadata object (for example changed field names). Passwords, tokens and card data are never logged.
- **FR-LOG-3** Activity logs are stored in MongoDB (see Section 6.5). Writing a log entry is asynchronous and must never make the original request fail.
- **FR-LOG-4** Moderators can search the logs through the API by user, action and date range, with pagination. Other roles cannot read logs.
- **FR-LOG-5** The application log uses Rails.logger in a structured format (JSON) with a request id, log levels, and no personal or payment data.

### 3.12 Subscriptions

A registered user can follow events and organizations to track changes.

- **FR-SUB-1** A logged-in user can subscribe to an event or to an organization and unsubscribe at any time. A subscription is unique per user and target. It is not possible to subscribe to an unpublished event or a blocked organization.
- **FR-SUB-2** Subscribers of an **organization** receive an email when the organization publishes a new event (after moderation approval) and when its public information changes.
- **FR-SUB-3** Subscribers of an **event** and holders of its tickets receive an email when an approved change affects the date, time, location or price, and when the event is cancelled.
- **FR-SUB-4** Notifications are sent only after the change is public (approved by moderation), asynchronously, in the user's preferred language, with a one-click unsubscribe link containing a signed token.
- **FR-SUB-5** A user can list their subscriptions. An in-app notification center is out of scope; notifications are sent by email only. Blocked users receive no notifications.

### 3.13 Event Reminders

- **FR-REM-1** About 24 hours before an event starts, a reminder email is sent to every user who subscribed to that event or holds a valid ticket for it. A user who is both receives one email.
- **FR-REM-2** A scheduled background job runs at least hourly. It selects published events starting within the next 24 hours and sends reminders. A reminder record (event, user, sent time) with a unique index prevents duplicates. If an event is approved less than 24 hours before the start, reminders are sent on the next run.
- **FR-REM-3** The email contains the event title, date and time in the event time zone, location or online link, and a link to the event page. Ticket holders also get a link to their ticket.
- **FR-REM-4** No reminders are sent for cancelled, blocked or unpublished events. If the start time changes after re-moderation, reminder records for the event are cleared so that new reminders are sent for the new date.

### 3.14 Ticket Check-in (QR Scanning)

- **FR-CHK-1** Organization owner and managers can check in visitors at the entrance: the client scans the QR code on the ticket and sends the decoded token to the API.
- **FR-CHK-2** The API verifies that the token exists, that the ticket belongs to the given event, that the event belongs to the caller's organization, that the event is not cancelled, and that the ticket status is `Valid`. On success the ticket becomes `Used`, `used_at` and `checked_in_by` are saved, and the response contains the holder name and ticket type.
- **FR-CHK-3** Errors are distinguishable by code: unknown token (404), ticket of another event (422), ticket already used (409, with the time of the first check-in), ticket cancelled (422).
- **FR-CHK-4** Check-in is atomic (a conditional update from `Valid` to `Used`), so two simultaneous scans of one ticket cannot both succeed.
- **FR-CHK-5** Owner and managers can see per event how many tickets were sold and how many were checked in. Offline scanning is out of scope.

### 3.15 Localization

- **FR-I18N-1** The platform supports two languages: Ukrainian (`uk`, the default) and English (`en`).
- **FR-I18N-2** The client selects the language with the `Accept-Language` header or a `locale` query parameter. A user can save a preferred language in the profile; it is used for emails and PDF tickets. If nothing is specified, Ukrainian is used.
- **FR-I18N-3** API messages, validation errors, emails and PDF tickets are translated with Rails I18n (`uk.yml`, `en.yml`). Error codes stay language-independent.
- **FR-I18N-4** Event and organization content is stored per language in translation tables. Ukrainian is required, English is optional; if English is missing the API returns the Ukrainian text. Category names exist in both languages.
- **FR-I18N-5** Moderation covers all languages of an event or organization. Dates are returned in ISO 8601 and amounts in minor units; formatting is done by the client.

### 3.16 Appeals of Blocked Users

- **FR-APP-1** When a blocked user logs in with correct credentials, the API answers 403 with the code `USER_BLOCKED`, the block reason and a short-lived appeal token (for example 24 hours). This token allows only the appeal endpoints; all other endpoints stay closed.
- **FR-APP-2** The owner of a blocked organization is not blocked themselves, so they use their normal login and submit an appeal for the organization (the request contains the organization id). Managers cannot appeal.
- **FR-APP-3** An appeal has a message (required, up to 2000 characters). Only one open appeal per blocked user or organization is allowed.
- **FR-APP-4** After an appeal is rejected, a new appeal for the same block can be submitted only after 1 day (24 hours). Before that the API returns an error that contains the time when a new appeal becomes possible.
- **FR-APP-5** Resource Moderators process appeals in a separate queue. Where possible, the decision is made by a moderator other than the one who blocked the user or organization.
- **FR-APP-6** A moderator accepts the appeal or rejects it (a reason is required). Accepting unblocks the user, or restores the organization to `Approved`, so its published events become visible again and ticket sales resume. The user or organization owner is notified by email in their preferred language.
- **FR-APP-7** The appellant can check the appeal status and the decision. Appeals and decisions are written to the moderation log and the activity log.

## 4. Event Creation Lifecycle

The event creation process is modelled as a state machine.

### 4.1 Statuses

| Status | Meaning | Visibility |
| --- | --- | --- |
| **Draft** | The creator started filling in the event or saved it for later. Not submitted. | Creator (and own organization's owner/managers) only |
| **Pending (In Progress)** | A multi-step creation wizard is in progress: data is being validated or media files (banners, photos) are being uploaded. | Creator only |
| **Under Review** | Submitted for moderation. Editing is locked until a decision. | Organization staff and moderators |
| **Published (Active)** | Approved and visible to everyone. Tickets can be purchased. | Public |
| **Failed** | A system error occurred while saving (e.g., database unavailable, uniqueness or time validation failed); the event was not created. | Creator only |
| **Cancelled** | The creation process was interrupted or cancelled by the user; entered data was discarded or moved to the draft archive. | Creator only |

### 4.2 Recommended Additional Statuses

The statuses above describe the *creation* process. The platform also needs statuses for the rest of the event life:

- **Rejected** — a moderator declined publication (with reason); the creator can edit and resubmit.
- **Cancelled by Organizer** — a published event was cancelled; ticket holders are notified. Use a distinct name or flag so it is not confused with the creation-time *Cancelled*.
- **Completed** — the event end time has passed (can be derived from dates instead of stored).

### 4.3 Allowed Transitions

- `Draft → Pending` when the creator starts the wizard or uploads media.
- `Pending → Under Review` when all required fields pass validation and the creator submits.
- `Pending → Failed` on a system or validation error (error code and message are stored).
- `Failed → Draft` the creator can retry; data is preserved where possible.
- `Draft | Pending → Cancelled` on user cancellation.
- `Under Review → Published | Rejected` by a moderator only.
- `Rejected → Draft` the creator edits and resubmits.
- `Published → Cancelled by Organizer` by owner/manager.

* Re-moderation: editing a `Published` event does **not** change its status. The changes are saved as a pending revision with status `Under Review`, while the last approved version stays public and tickets stay on sale. A moderator then approves the revision (the changes become public) or rejects it with a reason (the public version is unchanged, and the editor can correct and resubmit). Revision statuses: `Under Review → Approved | Rejected | Withdrawn`.

**Implementation note:** `Pending`, `Failed` and creation-time `Cancelled` are largely *transient* states. Teams may persist them with timestamps and an error field, or keep them as client-side/wizard-session states while only `Draft`, `Under Review`, `Published`, `Rejected` and `Cancelled` are persisted. The chosen approach must be documented. Every status change must be recorded in a status-history table.

## 5. API Requirements

### 5.1 General Principles

- RESTful design over HTTPS, JSON request/response bodies, UTF-8.
- Versioned base path, e.g. `/api/v1/`.
- Standard HTTP status codes: 200, 201, 204, 400, 401, 403, 404, 409, 422, 429, 500.
- Unified error format, e.g. `{ "code": "EVENT_SOLD_OUT", "message": "...", "details": [...] }`; validation errors list the offending fields.
- Pagination via `page` and `pageSize` with total count in the response; filtering and sorting via query parameters.
- All timestamps stored in UTC and returned in ISO 8601.
- Input validation on every endpoint; protection against SQL injection, XSS and mass-assignment (use strong parameters and serializers, never expose ActiveRecord models directly).
- CORS configuration; rate limiting on authentication and purchase endpoints.
- Idempotency for purchase requests (e.g., `Idempotency-Key` header) to avoid duplicate orders on retries.
- Interactive OpenAPI/Swagger documentation.

* Localization: the client sends `Accept-Language: uk` or `en` (or a `locale` query parameter); the default is `uk`. Messages, emails and PDF tickets use that language; error `code` values stay the same in every language.

### 5.2 Endpoint Overview

The list is indicative; the team may refine names and paths.

**Authentication and profile**

| Method | Path | Access | Description |
| --- | --- | --- | --- |
| POST | /auth/register | Guest | Register, send confirmation email |
| POST | /auth/confirm-email | Guest | Confirm email by token |
| POST | /auth/resend-confirmation | Guest | Resend confirmation email |
| POST | /auth/login | Guest | Obtain access and refresh tokens |
| POST | /auth/refresh | Any | Refresh the access token |
| POST | /auth/logout | User | Revoke refresh token |
| POST | /auth/forgot-password, /auth/reset-password | Guest | Password reset flow |
| GET | /users/me | User | View own profile |
| PUT | /users/me | User | Update profile (email excluded) |

**Events**

| Method | Path | Access | Description |
| --- | --- | --- | --- |
| GET | /events | Guest | List published events (filters, sorting, paging) |
| GET | /events/{id} | Guest | Event details |
| GET | /categories | Guest | List event categories |
| GET | /organizations/{orgId}/events | Owner/Manager | Own events in any status |
| POST | /organizations/{orgId}/events | Owner/Manager | Create event (Draft) |
| PUT | /organizations/{orgId}/events/{id} | Owner/Manager | Update event (a published event: save a pending revision and send it to moderation) |
| DELETE | /organizations/{orgId}/events/{id} | Owner/Manager | Delete / cancel event |
| POST | /organizations/{orgId}/events/{id}/submit | Owner/Manager | Submit for moderation |
| POST | /organizations/{orgId}/events/{id}/images | Owner/Manager | Upload event images |
| GET | /organizations/{orgId}/events/{id}/tickets | Owner/Manager | Sold tickets / participants |

**Tickets and orders**

| Method | Path | Access | Description |
| --- | --- | --- | --- |
| POST | /events/{id}/orders | User | Create order, reserve tickets, create monobank invoice (free events: issue tickets at once); returns the payment page URL |
| GET | /orders/my | User | List own orders with payment status |
| GET | /orders/{id} | Order owner | Order details and current payment status |
| POST | /payments/monobank/webhook | monobank (signature verified) | Receive payment status updates |
| GET | /tickets/my | User | List purchased tickets |
| GET | /tickets/{id} | Ticket owner | Ticket details with QR code data |
| GET | /tickets/{id}/qr | Ticket owner | QR code image (PNG or SVG) |
| GET | /tickets/{id}/pdf | Ticket owner | Download PDF ticket |
| POST | /organizations/{orgId}/events/{id}/check-in | Owner/Manager | Validate a ticket by its scanned QR token and mark it as used |
| GET | /organizations/{orgId}/events/{id}/check-in/stats | Owner/Manager | Tickets sold and checked in |

**Reviews and questions**

| Method | Path | Access | Description |
| --- | --- | --- | --- |
| GET | /events/{id}/reviews | Guest | List event reviews |
| POST | /events/{id}/reviews | User (attended) | Create event review |
| PUT / DELETE | /reviews/{id} | Author | Edit / delete review |
| GET | /organizations/{id}/reviews | Guest | List organization reviews |
| POST | /organizations/{id}/reviews | User (attended) | Create organization review |
| GET | /events/{id}/questions, /organizations/{id}/questions | Guest | List questions with answers |
| POST | /events/{id}/questions, /organizations/{id}/questions | User | Ask a question |
| POST | /questions/{id}/answers | Owner/Manager/Moderator | Answer a question |

**Organizations**

| Method | Path | Access | Description |
| --- | --- | --- | --- |
| GET | /organizations, /organizations/{id} | Guest | List / view approved organizations |
| POST | /organizations | User | Request organization creation |
| PUT | /organizations/{id} | Owner | Update organization info |
| GET | /organizations/{id}/managers | Owner | List managers |
| POST | /organizations/{id}/managers | Owner | Add manager |
| DELETE | /organizations/{id}/managers/{userId} | Owner | Remove manager |
| POST | /organizations/{id}/ownership-transfers | Owner | Start ownership transfer to a user by email (later phase) |
| POST | /ownership-transfers/{id}/accept, /decline | Recipient | Accept or decline the transfer |
| DELETE | /ownership-transfers/{id} | Owner | Cancel a pending transfer |

**Subscriptions**

| Method | Path | Access | Description |
| --- | --- | --- | --- |
| POST | /subscriptions | User | Subscribe to an event or organization (target type and id) |
| DELETE | /subscriptions/{id} | Subscriber | Unsubscribe |
| GET | /subscriptions/my | User | List own subscriptions |
| GET | /subscriptions/unsubscribe?token=... | Guest | One-click unsubscribe from an email link |

**Appeals (blocked users)**

| Method | Path | Access | Description |
| --- | --- | --- | --- |
| POST | /appeals | Blocked user (appeal token) or owner of a blocked organization | Submit an appeal (organization id for organization appeals) |
| GET | /appeals/current | Same | Appeal status, decision and the time when a new appeal is allowed |

**Moderation**

| Method | Path | Access | Description |
| --- | --- | --- | --- |
| GET | /moderation/organizations?status=pending | Moderator | Organization queue |
| POST | /moderation/organizations/{id}/approve, /reject | Moderator | Decision |
| GET | /moderation/events?status=under\_review | Moderator | Queue of new events |
| POST | /moderation/events/{id}/approve, /reject | Moderator | Decision |
| GET | /moderation/event-revisions?status=under\_review | Moderator | Queue of edits of published events (old and new values) |
| POST | /moderation/event-revisions/{id}/approve, /reject | Moderator | Decision (reason required for rejection) |
| GET | /moderation/questions | Moderator | Platform questions |
| POST | /moderation/users/{id}/block, /unblock | Moderator | Block / unblock a user (reason required) |
| POST | /moderation/organizations/{id}/block, /unblock | Moderator | Block / unblock an organization (reason required) |
| GET | /moderation/appeals?status=open | Moderator | Appeal queue (users and organizations) |
| POST | /moderation/appeals/{id}/accept, /reject | Moderator | Decide on an appeal (reason required for rejection) |
| GET | /moderation/activity-logs | Moderator | Search activity logs (user, action, date range) |

## 6. Database Requirements

### 6.1 General Rules

- Relational schema in at least Third Normal Form; primary keys on all tables (UUID or bigint identity); foreign keys with explicit `ON DELETE` behavior.
- Schema is created and changed only through ActiveRecord migrations (schema file committed); a seed script provides roles, categories, a moderator account and sample data.
- Audit columns: `created_at`, `updated_at`; soft delete (`deleted_at`) for entities referenced by orders or reviews.
- Indexes on foreign keys and on frequent filters (event date, status, category, city, organization).
- Unique and check constraints enforce business rules (see 6.4).

### 6.2 Core Entities

| Entity | Key fields | Notes |
| --- | --- | --- |
| **User** | id, email (unique), password\_hash, first\_name, last\_name, phone, birth\_date, avatar\_url, preferred\_locale (uk / en), is\_email\_confirmed, is\_active, blocked\_at, blocked\_by, block\_reason, platform\_role (User / Moderator), created\_at | Email is immutable |
| **EmailToken** | id, user\_id, type (Confirm / Reset), token\_hash, expires\_at, used\_at | Single-use tokens |
| **RefreshToken** | id, user\_id, token\_hash, expires\_at, revoked\_at |  |
| **Organization** | id, slug (unique), logo\_url, contact\_email, phone, website, address, status (PendingApproval / Approved / Rejected / Blocked), blocked\_at, blocked\_by, block\_reason, owner\_id → User (unique), created\_at | One owner per organization |
| **OrganizationManager** | organization\_id, user\_id, added\_by, added\_at | Composite PK (organization\_id, user\_id) |
| **Category** | id, slug (unique), name\_uk, name\_en | Reference table |
| **Event** | id, organization\_id, category\_id, created\_by, start\_at, end\_at, time\_zone, location\_type (Offline / Online), address, city, online\_url, banner\_url, status, rejection\_reason, published\_at, created\_at, updated\_at | Check: end\_at > start\_at |
| **EventImage** | id, event\_id, url, sort\_order | Gallery |
| **EventStatusHistory** | id, event\_id, from\_status, to\_status, changed\_by, reason, error\_code, changed\_at | Audit of the state machine |
| **TicketType** | id, event\_id, name, price, currency, total\_quantity, sold\_quantity, sale\_start\_at, sale\_end\_at | Check: sold\_quantity ≤ total\_quantity, price ≥ 0 |
| **Order** | id, user\_id, event\_id, total\_amount, currency, status (Pending / Paid / Failed / Expired / Refunded), reserved\_until, idempotency\_key, created\_at |  |
| **OrderItem** | id, order\_id, ticket\_type\_id, quantity, unit\_price |  |
| **Ticket** | id, order\_item\_id, user\_id, event\_id, code (unique), qr\_token (unique), status (Valid / Used / Cancelled), issued\_at, used\_at, checked\_in\_by → User | One row per ticket |
| **Payment** | id, order\_id, provider (monobank), invoice\_id (unique), page\_url, amount (minor units), currency, status, err\_code, failure\_reason, remote\_modified\_at, last\_webhook\_payload, created\_at | One or more per order (retries) |
| **EventReview** | id, event\_id, user\_id, rating (1–5), text, created\_at | Unique (event\_id, user\_id) |
| **OrganizationReview** | id, organization\_id, user\_id, rating (1–5), text, created\_at | Unique (organization\_id, user\_id) |
| **Question** | id, author\_id, target\_type (Event / Organization / Platform), target\_id, text, is\_hidden, created\_at |  |
| **Answer** | id, question\_id, author\_id, text, created\_at |  |
| **ModerationLog** | id, entity\_type, entity\_id, moderator\_id, decision, reason, created\_at |  |
| **EmailOutbox** | id, to\_email, template, payload, status, attempts, last\_error, created\_at, sent\_at | Optional, for reliable async email |
| Subscription | id, user\_id, target\_type (Event / Organization), target\_id, created\_at | Unique (user\_id, target\_type, target\_id) |
| EventReminder | id, event\_id, user\_id, sent\_at | Unique (event\_id, user\_id); prevents duplicate reminders |
| EventTranslation | id, event\_id, locale (uk / en), title, description | Unique (event\_id, locale); uk is required |
| OrganizationTranslation | id, organization\_id, locale (uk / en), name, description | Unique (organization\_id, locale); uk is required |
| EventRevision | id, event\_id, submitted\_by, payload (JSONB: translations, dates, location, images, ticket types), status (UnderReview / Approved / Rejected / Withdrawn), reviewed\_by, reviewed\_at, rejection\_reason, created\_at | At most one UnderReview revision per event (partial unique index) |
| OwnershipTransfer | id, organization\_id, from\_user\_id, to\_user\_id, status (Pending / Accepted / Declined / Cancelled / Expired), expires\_at, created\_at, responded\_at | One Pending transfer per organization; later phase |
| Appeal | id, target\_type (User / Organization), target\_id, submitted\_by, message, status (Open / Accepted / Rejected), decision\_reason, reviewed\_by, created\_at, reviewed\_at | One Open appeal per blocked user or organization; after a rejection a new appeal is allowed 24 hours later |

### 6.3 Relationships (summary)

- User 1—N Organization (as owner); User N—M Organization through OrganizationManager.
- Organization 1—N Event; Category 1—N Event; Event 1—N TicketType, EventImage, EventStatusHistory.
- User 1—N Order; Order 1—N OrderItem; OrderItem 1—N Ticket; Order 1—N Payment.
- User 1—N EventReview / OrganizationReview; Event 1—N EventReview; Organization 1—N OrganizationReview.
- Question 1—N Answer; a Question targets an Event, an Organization, or the platform.

* User N—M Event and User N—M Organization through Subscription; Event N—M User through EventReminder.
* Event 1—N EventTranslation; Organization 1—N OrganizationTranslation (one row per language).
* Ticket N—1 User through checked\_in\_by (the owner or manager who scanned it).

- Event 1—N EventRevision; Organization 1—N OwnershipTransfer (between two users); User and Organization 1—N Appeal.

### 6.4 Business Rules Enforced in the Database

- Unique email; unique (event\_id, user\_id) and (organization\_id, user\_id) for reviews; unique ticket code.
- `sold_quantity` never exceeds `total_quantity` (check constraint plus transactional update with row locking or optimistic concurrency).
- A review requires a ticket for the event: enforced in the service layer, optionally backed by a database check or trigger.
- A manager cannot be the owner of the same organization (service-level validation).

* One organization per owner: unique index on organizations.owner\_id.
* Unique (user\_id, target\_type, target\_id) for subscriptions; unique (event\_id, user\_id) for reminders; unique (entity\_id, locale) for translations.
* Ticket check-in is a single conditional update (status Valid to Used) so a ticket cannot be used twice.
* A blocked user or organization keeps all its data; blocking only changes status fields.

- At most one pending revision per event, one pending ownership transfer per organization and one open appeal per blocked user or organization (partial unique indexes).

### 6.5 Activity Log Storage (MongoDB)

Activity logs (Section 3.11) are stored in the MongoDB collection `activity_logs`, one document per action. PostgreSQL remains the source of truth for business data. A relational `activity_logs` table is an acceptable fallback if MongoDB is unavailable in a team's environment.

```json
{
  "timestamp": "2026-10-26T10:15:00Z",
  "user_id": 42,
  "role": "user",
  "action": "user.login",
  "entity_type": "User",
  "entity_id": 42,
  "result": "success",
  "ip": "203.0.113.10",
  "user_agent": "Mozilla/5.0",
  "request_id": "b1c2d3e4",
  "metadata": {}
}
```

- Indexes: (user\_id, timestamp), (action, timestamp), (entity\_type, entity\_id).
- Optional TTL index to delete entries after a retention period (for example 12 months).
- Documents are append-only; the application never updates or deletes them.
- Logs contain personal data (IP address), so access is limited to moderators.

## 7. Non-Functional Requirements

- **Security:** HTTPS only, hashed passwords, token expiry, role checks on every endpoint, no sensitive data in logs, secrets in environment variables.
- **Performance:** list endpoints respond in under 500 ms for 10,000 events on a typical development machine; use pagination and indexes.
- **Reliability:** transactional ticket purchase; email failures must not roll back a successful purchase (retry via outbox).
- **Maintainability:** Rails conventions with thin controllers and service objects, serializers for responses, consistent naming, and Rubocop with one shared configuration.
- **Testing:** RSpec model, service and request specs for business logic (purchase, payment webhook, review eligibility, status transitions) and key API flows, with the monobank API stubbed; Jest for JavaScript code; at least 70% coverage of services.
- **Observability:** structured logging, correlation id per request, health-check endpoint.
- **Deployment:** Docker Compose setup for the Rails API, PostgreSQL and MongoDB; configuration via environment variables; CI pipeline running Rubocop, RSpec and Jest.
- **Documentation:** README with setup instructions, ER diagram, and OpenAPI specification.

## 8. Suggested Delivery Phases

1. **Foundation:** project skeleton, database schema and migrations, authentication, email confirmation, profile.
2. **Organizations and events:** organization request and moderation, event CRUD, event statuses, public event listing and details.
3. **Tickets:** order and monobank payment flow with webhook, free tickets, concurrency control, PDF and QR generation, email delivery, my tickets, QR check-in.
4. **Community features:** reviews, Q&A, subscriptions, event reminders, blocking, appeals and localization.
5. **Hardening:** ownership transfer, tests, rate limiting, documentation, Docker, CI.

## 9. Assumptions and Open Questions

**Confirmed decisions**

- The monobank integration is limited to the test environment for the whole internship, with one shared test token.
- Refunds and buyer-side cancellation of tickets are not supported yet.
- Any edit of a published event triggers re-moderation.
- Paid and free events are both supported; there is no per-user ticket limit; each event has a fixed number of tickets.
- Ticket check-in by QR scanning is in scope for organizers.
- Content is available in Ukrainian (default) and English.
- Moderators can block users and organizations.
- Registered users can subscribe to events and organizations; a reminder email is sent one day before the event to subscribers and ticket holders.
- Frontend: React + TypeScript + Tailwind CSS. Repository: [UA-5382-Ruby/come2kids](https://github.com/UA-5382-Ruby/come2kids).

* A user can own only one organization; ownership can be transferred later (FR-ORG-8).
* When an organization is blocked, its events are hidden and sales stop; sold tickets are not refunded automatically.
* While an edit of a published event is under review, the last approved version stays public (pending revision, FR-EM-3).
* Reminders go only to event subscribers and ticket holders, not to organization subscribers.
* English translations of content are optional; Ukrainian is used when they are missing.
* A blocked user can appeal; appeals are processed by a Resource Moderator in a separate process (Section 3.16).

- The owner of a blocked organization can also appeal, through the same moderator process.
- After an ownership transfer the previous owner becomes a manager, and the new owner can remove them.
- A rejected appeal can be resubmitted after 1 day.

**Open questions and assumptions to confirm**

No open questions at the moment: all earlier questions are resolved and recorded in the confirmed decisions above.
