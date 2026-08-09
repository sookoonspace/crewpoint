Step 1: Enable the Pub/Sub API via Cloud Shell
Instead of clicking around the Google Cloud Console three times for dev, staging, and production, you can execute this instantly in the Google Cloud Shell for each project.

1. Open the GCP Console.

2. Select your target project (crewpoint-dev, crewpoint-stg, or crewpoint-prod) using the project picker at the top.

3. Click the Activate Cloud Shell icon (the >_ symbol) in the top right header.

4. Run the following command to enable the Pub/Sub API:

gcloud services enable pubsub.googleapis.com

5. Repeat this process for all three projects. This instantly prepares your backend for the upcoming scheduled tasks and cron triggers[cite: 8].

---

## Step 2: Set a Cost-Monitoring Budget Alert
We need a strict circuit breaker to ensure serverless background operations don't run away with your equity.

1. In the GCP Console navigation menu (hamburger icon), go to **Billing** -> **Budgets & alerts**.
2. Click **+ Create Budget**.
3. Under **Scope**:
   * **Name:** `CrewPoint Monthly Safety Budget`
   * **Projects:** Select all three environments or create an isolated budget for `crewpoint-prod`.
4. Under **Amount**:
   * Set **Budget type** to *Specified amount*.
   * Enter your absolute hard ceiling for monthly cloud spend (e.g., `$50.00` or `$100.00`).
5. Under **Actions (Alert Thresholds)**:
   * Set up three standard percentage triggers based on your amount:
     * **50%:** (Muted notice)
     * **90%:** (High Alert)
     * **100%:** (Hard Breach)
   * Ensure **Email alerts** are checked so you receive an immediate notification the second a budget threshold is crossed.

---

## Step 3: Capture the Firestore Composite-Index URL on First Deploy
When you implement complex queries—such as looking up net balances or sorting tasks by status, assignee, and due date across events—Firestore requires a multi-field composite index. If the index doesn't exist, the query will throw an error.

The absolute easiest way to create these indexes without writing manually configured JSON rules files is to let Firebase generate the link for you:

1. When ACT or Claude deploys the newly refactored Riverpod aggregators to your staging or production environments, intentionally run a test flow that executes the new multi-filter query.
2. Because the index is missing, the query will fail immediately in the app, but **Firestore will catch this and log a precise error**.
3. Open your local terminal (or your Cloud Function logging portal) and inspect the logs[cite: 8]. You will see a native Firebase error resembling this:
   ```text
   FAILED_PRECONDITION: The query requires an index. You can create it here: 
   https://console.firebase.google.com/v1/r/project/crewpoint-stg/databases/(default)/indexes?create_composite=...