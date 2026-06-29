# 📱 Whispr Mobile Application – Production Specification

## 🎯 Project Overview

We are building the complete mobile application version of:

https://whisprwords.com

This is a production-ready web platform.
We are NOT rebuilding backend.

We are building a scalable, production-grade Flutter mobile client
that consumes the existing API:

https://whisprwords.com/api/

The backend repository:
https://github.com/TECHTUNE-I-T-SOLUTIONS/whispr.git

All routes, payloads, and structures must match the backend.

---

## 🧱 Tech Stack

Frontend:
- Flutter (latest stable)
- Clean Architecture
- Riverpod (state management)
- Dio (HTTP client)
- GoRouter (routing)
- Flutter Secure Storage (auth tokens)
- Share Plus (social sharing)
- Paystack Flutter SDK (premium payments)
- Dark mode support
- Tablet responsiveness

Backend:
- Next.js API (existing)
- Supabase (existing database)

We are ONLY building frontend mobile client.

---

## 🎨 Brand Theme (MANDATORY)

Primary Color:
- Dark Red: #911A1B

Light Mode:
- Background: White
- Text: Black
- Primary buttons: #911A1B
- Card elevation with soft shadows
- Clean spacing and professional typography

Dark Mode:
- Background: Black
- Card: #111111
- Text: White
- Accent: #911A1B
- Smooth animated transitions

Design must:
- Look premium
- Not look AI-generated
- Not look template-based
- Be minimal but powerful
- Use custom bottom navigation (curved or floating style)
- Support phones and tablets

---

## 🏗 Folder Structure

lib/
  core/
    theme/
    constants/
    network/
    utils/
  features/
    auth/
    home/
    chronicles/
    whispr_wall/
    notifications/
    profile/
    premium/
  shared/
    widgets/
  main.dart

---

## 📱 Screens Required

Public:
- Splash screen
- Onboarding
- Home feed (admin blogs + chronicles posts merged)
- Public post view
- Creator profile view

Auth:
- Login
- Multi-step Signup (mirroring web)
- Password recovery

Authenticated:
- Dashboard
- Create Chronicle (rich editor)
- Whispr Wall
- Notifications
- Settings
- Premium Upgrade
- Engagement (like/comment/share)

---

## 🧭 Navigation

Bottom Navigation Tabs:
- Home
- Chronicles
- Whispr Wall
- Notifications
- Profile

Custom animated navigation.
Professional transitions.
No generic Material default.

---

## 🔌 API Integration

Base URL:
https://whisprwords.com/api/

Create structured services:
- AuthService
- PostService
- EngagementService
- WhisprService
- PremiumService
- NotificationService

All requests must:
- Handle errors properly
- Support token authentication
- Parse JSON safely
- Handle loading & retry states

---

## 💳 Premium System

- Integrate Paystack
- On successful payment:
  - Verify via backend
  - Update premium flag
- Lock premium features via backend validation

---

## 📤 Sharing

Use share_plus.

Support:
- TikTok
- WhatsApp
- Instagram
- Twitter
- Facebook

Share dynamic links pointing back to whisprwords.

---

## ⚙ Development Workflow

During development:

Backend runs at:
http://10.0.2.2:3000/api/

Flutter must support switching between:
- Local development
- Production API

Use environment config system.

---

## 🎯 Deliverables

Generate:
1. Initial project structure
2. Theme configuration
3. Main.dart setup
4. Router configuration
5. Bottom navigation implementation
6. API service base class
7. Authentication flow

All code must be:
- Production ready
- Scalable
- Clean
- Well structured
- Commented professionally
