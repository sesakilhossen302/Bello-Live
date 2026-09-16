# Data Deletion & Data Retention Policy for ProLive

**Effective Date:** July 23, 2026  
**Last Updated:** July 23, 2026  
**Package Name:** `com.liveapp.com`

This **Data Deletion Policy** describes how **ProLive** handles the deletion, purging, and retention of user data when an account is deleted or when data retention periods expire.

---

## 1. User Right to Data Erasure

In accordance with global privacy regulations (GDPR, CCPA, and Google Play Data Policies), all users of **ProLive** have the right to request the permanent deletion of their personal information and user-generated content.

---

## 2. Categories of Data Deleted Upon Account Erasure

When a user account deletion request is completed, the following data categories are **permanently purged** from our active production databases:

1. **Account Identification Data:** Display name, email address, phone number, password hashes, profile avatar, gender, date of birth, and biography.
2. **User-Generated Content:** Uploaded status feed photos/videos, bio posts, public comments, and uploaded audio/video files.
3. **Communication Data:** Direct 1-on-1 chat logs, voice messages, and inbox notification records.
4. **Social & Room Data:** Friend lists, follower/following connections, profile visitor logs, and room history.
5. **Virtual Balances:** Unused coin balances, earned diamonds, store inventory, VIP status history, and level progress (forfeited).

---

## 3. Data Purging Timeline

- **Immediate Action:** Upon confirming deletion, your account is immediately deactivated, preventing any login, broadcast, or room participation.
- **Active Database Purge:** Personal profiles, chat messages, and social connections are deleted from primary cloud databases (Firebase Cloud Firestore / Realtime DB) within **30 days**.
- **Backup & Server Log Rotation:** Residual data in encrypted server backups and cold storage archives is overwritten and permanently purged within **60 to 90 days** as part of standard server maintenance.

---

## 4. Retained Data Exemptions (Legal & Financial Requirements)

Certain limited data may be retained after account deletion where strictly required by applicable law, safety regulations, or financial auditing:

- **In-App Transaction Receipts:** Google Play purchase receipts, top-up transaction IDs, and payout logs are retained for **up to 7 years** to comply with tax, financial auditing, and anti-money laundering (AML) laws.
- **Safety & Abuse Reports:** Aggregated logs related to fraudulent activity, child exploitation reports, severe community violations, or legal subpoenas are retained in anonymized form to maintain platform security and assist law enforcement.

---

## 5. How to Initiate Data Deletion

Users can request data deletion through two methods detailed in our [Account Deletion Guide](ACCOUNT_DELETE.md):
- **In-App:** Profile > Settings > Account & Security > Delete Account.
- **Email Request:** Send an email to **`support@smartliveapp.com`** with subject *"Data Deletion Request"*.

---

## 6. Contact Us

For questions regarding data retention or data privacy practices:
- **App Name:** ProLive (`com.liveapp.com`)
- **Privacy Email:** `support@smartliveapp.com`
- **Privacy Policy:** [PRIVACY_POLICY.md](PRIVACY_POLICY.md)
---
