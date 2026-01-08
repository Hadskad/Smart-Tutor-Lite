# Subscription Feature

## Overview
This feature provides a beautiful, horizontally scrollable subscription plans page that allows users to view and select different subscription tiers for the Smart Tutor Lite app.

## Structure

```
lib/features/subscription/
├── presentation/
│   ├── pages/
│   │   └── subscription_page.dart          # Main subscription page
│   ├── widgets/
│   │   └── subscription_plan_card.dart     # Individual plan card widget
│   └── models/
│       └── subscription_plan.dart          # Plan data model
└── README.md
```

## Features

### Subscription Plans

#### 1. **Starter Plan (FREE)**
- Limited access to Summaries
- Limited access to Quiz generation
- Limited access to Flashcards
- Create up to 5 study folders

#### 2. **Active Student Plan (₦3,000/month)** - POPULAR
- Unlimited offline lecture transcription
- Includes access to AI Note Taker (Usage based)
- 5× more usage for Summaries, Quizzes, Flashcards
- Create up to 25 study folders
- Up to 8 hours of AI-generated lecture notes

#### 3. **Power Learner Plan (₦10,000/month)**
- Unlimited offline lecture transcription
- Unlimited study folders
- 2× more AI Note Taker usage
- 10× more usage for Summaries, Quizzes, Flashcards
- Up to 16 hours of AI-generated lecture notes

#### 4. **All-Access Plan (₦30,000/month)**
- Includes Audio Notes feature
- Unlimited offline lecture transcription
- Unlimited study folders
- 4× more AI Note Taker usage
- 50× more usage for Summaries, Quizzes, Flashcards
- Up to 32 hours of AI-generated lecture notes

## UI Features

- **Horizontal PageView**: Swipeable cards showing one plan at a time
- **Popular Badge**: Highlights the most popular plan (Active Student)
- **Color-coded Plans**: Each plan has a unique accent color
- **Responsive Design**: Works on different screen sizes
- **Plan Indicators**: Visual dots showing total plans available
- **Gradient Buttons**: Eye-catching subscribe buttons
- **Checkmark Perks**: Each perk has a styled checkmark icon

## Navigation

Access the subscription page from:

1. **Settings Page** → "Upgrade to Unlimited" button
2. **Settings Page** → "Manage Subscription" tile
3. **Programmatically**: `Navigator.pushNamed(context, AppRoutes.subscription)`

## Color Scheme

The page uses the app's consistent color palette:
- **Background**: `AppColors.background` (#1E1E1E)
- **Cards**: `AppColors.card` (#333333)
- **Accent Blue**: `AppColors.accentBlue` (#00BFFF)
- **Accent Coral**: `AppColors.accentCoral` (#FF7043)
- **Gold** (for Max plan): #FFD700
- **Text**: White and light gray variants

## TODO - Future Implementation

The following features need to be implemented:

1. **Payment Integration**
   - Connect to payment gateway (Paystack, Flutterwave, etc.)
   - Handle subscription purchase flow
   - Store subscription status in backend

2. **Subscription State Management**
   - Create subscription BLoC/Cubit
   - Track current user subscription
   - Handle subscription status updates

3. **Backend Integration**
   - API endpoints for subscription management
   - Verify payment status
   - Update user subscription tier

4. **Feature Gating**
   - Implement usage limits based on subscription tier
   - Lock/unlock features based on plan
   - Track usage metrics

5. **Trial Period**
   - Implement 7-day free trial logic
   - Remind users before trial ends

## Design Reference

The design is inspired by modern subscription UIs with:
- Card-based layouts
- Smooth horizontal scrolling
- Clear pricing hierarchy
- Feature comparison made easy
- Emphasis on the most popular plan
