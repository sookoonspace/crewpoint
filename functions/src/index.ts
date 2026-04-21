import * as admin from "firebase-admin";

// Initialize Firebase Admin SDK (once, before any function imports)
admin.initializeApp();

// === Account Functions ===
export {deleteUserAccount} from "./account/deleteUserAccount";

// === Notification Functions ===
// export {sendPushNotification} from "./notifications/sendPushNotification";

// === Event Functions ===
// export {onEventCreated} from "./events/onEventCreated";
