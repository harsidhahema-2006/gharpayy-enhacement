# Gharpayy Dashboard

## Overview
Gharpayy Dashboard is a comprehensive administration and management system built for Gharpayy. It provides a centralized web-based application to handle various operational aspects, including leads, inventory, properties, bookings, and user analytics.

## Features
- **Authentication & Authorization**: Secure login, signup, and password reset functionalities.
- **Analytics & Reporting**: Data-driven insights and historical logs for business performance metrics.
- **CRM Pipeline**: Track and capture leads, manage conversations, and handle visits.
- **Inventory & Property Management**: Detailed property tracking, matching, and zone management.
- **Owner Portals**: Dedicated interfaces for tracking availability, handling owners, and managing bookings.

## Technology Stack
- **Frontend**: React 18, TypeScript, Vite
- **Styling**: Tailwind CSS, shadcn-ui, Radix UI
- **State Management**: TanStack React Query
- **Backend & Database**: Supabase
- **Routing**: React Router

## Local Setup Instructions

Follow these steps to run the dashboard application on your local machine.

### Prerequisites
- Node.js
- npm (Node Package Manager)
- Git

### 1. Clone the Repository
Open your terminal and clone the repository:
```sh
git clone <YOUR_GIT_URL>
```

### 2. Navigate to the Project Directory
```sh
cd gharpayy-flow
```

### 3. Install Dependencies
Install all required packages:
```sh
npm install
```

### 4. Configure Environment Variables
Create a `.env` file in the root directory of the project and add your Supabase credentials:
```env
VITE_SUPABASE_PROJECT_ID="your_project_id_here"
VITE_SUPABASE_PUBLISHABLE_KEY="your_publishable_key_here"
VITE_SUPABASE_URL="https://your_project_id_here.supabase.co"
```

### 5. Start the Development Server
Run the application in development mode:
```sh
npm run dev
```

The application will launch and you can view it in your browser, typically at `http://localhost:8080` (or another port specified in the terminal output).

## Production Readiness Upgrade

This project was enhanced to improve security, scalability, and operational readiness for production environments. The following upgrades were implemented as part of the Gharpayy production-readiness assignment.

### Security & Role Based Access Control
- Implemented a `user_roles` table supporting roles: **admin, manager, agent, owner, customer**
- Hardened **Row Level Security (RLS)** policies to ensure:
  - Agents only see assigned leads
  - Owners only see their own inventory
  - Customers only see their reservations

### Audit Logging
- Implemented a centralized `audit_log` table
- Database triggers automatically log updates to:
  - leads
  - bookings
  - properties
- Provides traceability for system actions.

### Persistent Chat System
- Refactored the `PropertyChat` component to persist messages in the database
- Integrated **Supabase Realtime** for instant updates across connected clients

### Background Automation
Scheduled jobs implemented using **pg_cron**:

- Expired reservation cleanup
- Nightly lead scoring recalculation
- Daily analytics snapshot generation

### Performance Improvements
Added indexes to optimize CRM operations:

- leads
- bookings
- visits
- properties

Implemented **PostgreSQL full-text search** for faster property search by city, area, and property attributes.

### Media & Storage
Implemented secure property image uploads:

- `PropertyImageUpload` component
- Multi-file uploads
- Stored in **Supabase Storage**
- Generated signed public URLs

### Observability & Error Handling
- Implemented a global **React ErrorBoundary**
- Prepared integration for **Sentry error monitoring**
- Improved logging and debugging capability

### Rate Limiting
Basic API rate limiting added to protect public endpoints such as:

- lead capture
- reservation requests
- chat messages

### Scalability Target
The upgraded system is designed to support:

- 30+ internal CRM users
- 100+ property owners
- 10,000+ daily visitors
