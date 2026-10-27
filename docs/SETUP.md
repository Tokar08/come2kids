# Environment Setup Guide

This document provides a comprehensive, step-by-step guide to setting up the local development environment for the **Come2Kids** project.

---

### 1. Install Ruby

We highly recommend using a Ruby version manager such as **RVM** or **ASDF** to ensure consistency across the team.

* **Option A: Using RVM**
```bash
\curl -sSL https://get.rvm.io | bash -s stable
rvm install 3.3.0
rvm use 3.3.0 --default
```


* **Option B: Using ASDF**
```bash
asdf plugin add ruby
asdf install ruby 3.3.0
asdf global ruby 3.3.0
```



---

### 2. Install Rails

Install the latest stable version of Rails required for this project.

```bash
gem install rails
rails --version
```
---

### 3. Install PostgreSQL

PostgreSQL is the primary database for this project.

1. Download the installer from the official website: [postgresql.org/download](https://www.postgresql.org/download/)
2. Run the installer and keep the default settings.
3. **Remember the password** you set for the default `postgres` user.
4. Add the PostgreSQL binary directory to your system `PATH`:
* **Windows:** `C:\Program Files\PostgreSQL\18\bin`
* **macOS/Linux:** Usually added automatically by the installer.
---

### 4. Create the Development Database

Open your terminal and connect to PostgreSQL:

```bash
psql -U postgres
```

Inside the `psql` interactive prompt, execute the following commands to create the development database:

```sql
CREATE DATABASE come2kids_dev;
\q
```

---

### 5. Clone and Setup the Project

Once all prerequisites are met, clone the repository and initialize the application.

```bash
git clone https://github.com/YOUR_USERNAME/come2kids.git
cd come2kids/api
bundle install
rails db:setup
rails server
```

> **Note:** The application should now be running and accessible at [http://localhost:3000](http://localhost:3000).