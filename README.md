# ⚖️ NyayaBridge: AI-Powered Legal Assistant Platform

**NyayaBridge** is a comprehensive legal tech platform designed to bridge the gap between citizens and the justice system. Built for the Hackathon, it utilizes advanced AI to simplify legal intake, automate document scanning, and provide emergency SOS features.

---

## 🚀 Live Status
* **Backend API (FastAPI + Gemini):** Deployed and live via Render.
* **Frontend App (Flutter):** Currently optimized for local hackathon demonstration (Compilation instructions below).

---

## 🌟 Key Features

### 🧑‍⚖️ Dual-Role Ecosystem
* **Client Portal:** Easy-to-use dashboard for legal consultation, SOS broadcasting, and document uploads.
* **Lawyer Portal:** Advanced case tracking, AI-assisted legal research, and client management.
* **Admin Dashboard:** System oversight and support ticketing.

### 🧠 Gemini AI Integration
* **Legal Intake Chatbot:** An intelligent AI chat system that helps clients articulate their legal issues before connecting them with a lawyer.
* **OCR Document Scanner:** Utilizes Gemini Vision to instantly scan, read, and extract crucial information from physical legal documents and receipts.
* **Lawyer AI Assistant:** Specialized prompts to help lawyers summarize long case files.

### 🚨 SOS Radar & Hardware Integration
* **Emergency Broadcast:** A one-tap SOS system for clients in immediate distress.
* **Native Overrides:** Triggers native OS audio sirens (via Firebase Admin) to alert nearby authorities or contacts.

---

## 🛠️ Technology Stack

**Frontend Framework:**
* Flutter & Dart (Cross-platform: Android, iOS, Web)

**Backend & AI:**
* Python (FastAPI, Uvicorn)
* Google GenAI SDK (Gemini 2.5 Pro Vision)
* Pillow (Image processing)

**Database & Cloud:**
* Firebase Authentication
* Cloud Firestore
* Render (Backend Hosting)

---

## 💻 Local Setup & Installation Instructions

To run this project locally for judging, please follow these steps:

### Prerequisites
* [Flutter SDK](https://docs.flutter.dev/get-started/install) installed.
* [Python 3.9+](https://www.python.org/downloads/) installed.

### 1. Run the FastAPI Backend (Local)
*(Note: The production backend is already hosted on Render, but you can run it locally for testing).*
```bash
cd backend
pip install -r requirements.txt
uvicorn main:app --reload

🔒 Security Note for Judges
For security compliance, sensitive keys (serviceAccountKey.json, .env, and production Gemini API keys) are strictly ignored via .gitignore and hosted securely in our private Render vault. Dummy placeholder keys are provided in the public codebase to ensure the application compiles successfully during evaluation without compromising database integrity.
