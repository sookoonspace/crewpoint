import {HttpsError} from "firebase-functions/v2/https";
import {DocumentData} from "firebase-admin/firestore";

/**
 * A module is on unless turned off, so events from before modules keep working.
 * Turning one off keeps its data (Req 22).
 */
export function isModuleOn(event: DocumentData, module: string): boolean {
  return event.modules?.[module] !== false;
}

export function assertModuleOn(event: DocumentData, module: string): void {
  if (!isModuleOn(event, module)) {
    throw new HttpsError(
      "failed-precondition",
      `This event has turned off ${module}.`
    );
  }
}
