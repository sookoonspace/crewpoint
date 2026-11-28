import {initializeApp} from "firebase-admin/app";

// Initialize Firebase Admin SDK (once, before any function imports)
initializeApp();

// === Account Functions ===
export {deleteUserAccount} from "./account/deleteUserAccount";

// === Event Functions ===
export {generateInviteCode} from "./events/generateInviteCode";
export {createInviteLink, updateInviteLink, listInviteLinks} from "./events/inviteLinks";
export {previewInvite} from "./events/previewInvite";
export {joinEvent} from "./events/joinEvent";
export {removeEventMember} from "./events/removeEventMember";
export {deleteEvent} from "./events/deleteEvent";
export {promoteToAdmin} from "./events/promoteToAdmin";
export {demoteAdmin} from "./events/demoteAdmin";
export {markTaskComplete} from "./events/markTaskComplete";
export {createEvent} from "./events/createEvent";
export {saveAsTemplate} from "./events/saveAsTemplate";
export {saveExpense} from "./events/saveExpense";
export {recordSettlement} from "./events/recordSettlement";
export {changeEventCurrency} from "./events/changeEventCurrency";
export {setMemberRoles, saveEventRole, deleteEventRole} from "./events/roles";
export {saveCrew, setCrewMembers, deleteCrew} from "./events/crews";
export {offerOwnership, acceptOwnership, cancelOwnershipOffer} from "./events/ownership";
export {disputeSettlement} from "./events/disputeSettlement";
export {setExpenseAccess, getMyBalance} from "./events/expenseAccessCallables";
export {onUrgentMessageCreated} from "./events/onUrgentMessageCreated";
export {onTaskAssigned} from "./events/onTaskAssigned";
export {onExpenseCreated} from "./events/onExpenseCreated";
export {onSettlementDisputed} from "./events/onSettlementDisputed";
export {onMemberJoined} from "./events/onMemberJoined";
export {onMemberProfileSync, onUserProfileSync} from "./events/profiles";
export {saveGroup, setGroupAdults, deleteGroup} from "./events/groups";
export {onImportQueued} from "./imports/onImportQueued";
export {cancelImportedGroups} from "./imports/cancelImportedGroups";
export {cleanupImports} from "./imports/cleanupImports";
export {linkMyParticipants, resolveLinkRequest} from "./participants/linkParticipants";
export {onTaskDueScheduled} from "./events/onTaskDueScheduled";
export {onEventStatusScheduled} from "./events/onEventStatusScheduled";
export {onDigestSummary} from "./events/onDigestSummary";
export {
  onCountsInputWritten,
  onCountsPrivateWritten,
  onCountsSettingsChanged,
  onCountsScheduled,
  recalculateCounts,
} from "./counts/functions";
export {exportRoster, freezeCounts} from "./counts/exportAndFreeze";
export {onChatMessageWritten} from "./chat/summary";
export {onMailQueued} from "./mail/send";
export {claimEventSlug, saveRegistrationSettings} from "./registration/registrationSettings";
export {eventPageHtml, getEventPage} from "./registration/eventPage";
export {submitRegistration} from "./registration/submitRegistration";
export {getRegistrationForm} from "./registration/registrationForm";
export {getMyRegistration, getMyWaitingRegistrations} from "./registration/myRegistration";
export {saveRegistrationDraft} from "./registration/registrationDraft";
export {updateRegistration} from "./registration/updateRegistration";
export {cancelRegistration} from "./registration/cancelRegistration";
export {saveWaiver, acceptWaivers, sendWaiverReminders} from "./registration/waiverCallables";
export {
  onPhotoConsentPersonWritten, onPhotoConsentAnswerWritten, onPhotoConsentGroupWritten,
} from "./participants/photoConsent";
export {
  respondToOffer, manageOffer, getWaitlist, onOffersScheduled, onTallyRecountScheduled, onCapacityRaised,
} from "./registration/offers";
export {
  getRegistrationSummary, manageRegistration, resendConfirmation, sendClosingReminder, getGroupRegistration,
} from "./registration/committee";
export {sendCompletionLink} from "./registration/completion";
export {sendSignInLink} from "./account/signInLink";
