import * as admin from "firebase-admin";

// Initialize Firebase Admin SDK (once, before any function imports)
admin.initializeApp();

// === Account Functions ===
export {deleteUserAccount} from "./account/deleteUserAccount";

// === Event Functions ===
export {generateInviteCode} from "./events/generateInviteCode";
export {joinEvent} from "./events/joinEvent";
export {removeEventMember} from "./events/removeEventMember";
export {deleteEvent} from "./events/deleteEvent";
export {promoteToAdmin} from "./events/promoteToAdmin";
export {demoteAdmin} from "./events/demoteAdmin";
export {markTaskComplete} from "./events/markTaskComplete";
export {disputeSettlement} from "./events/disputeSettlement";
export {onUrgentMessageCreated} from "./events/onUrgentMessageCreated";
export {onTaskAssigned} from "./events/onTaskAssigned";
export {onExpenseCreated} from "./events/onExpenseCreated";
export {onSettlementDisputed} from "./events/onSettlementDisputed";
