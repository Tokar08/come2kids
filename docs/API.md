# API Summary

This document provides an overview of the backend API architecture and current development status.

---

## Overview

The backend is built as a Rails API-only application, located in the `api/` directory. It is designed to serve JSON responses to frontend clients or external services.

---

## Current Status

The foundational API skeleton has been successfully generated. Core directories for models, controllers, policies, and tests are in place. Specific business logic endpoints will be implemented in subsequent tasks.

---

## Running the API

To start the local development server, navigate to the API directory and run:

```bash
cd api
rails server