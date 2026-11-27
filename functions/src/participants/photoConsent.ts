import {onDocumentWritten} from "firebase-functions/v2/firestore";
import {FieldValue, Firestore, getFirestore} from "firebase-admin/firestore";
import {isConfirmed} from "../counts/stats";

/**
 * Photo and video consent (Spec #233 Req 30, TD 12; #247). Each person's
 * answer is `photoConsent` (true or false) in their `private/details`,
 * unanswered when missing, and for a child given by a guardian. The server
 * keeps `events/{id}/photoConsent/current`: `people` by participant ID,
 * only those who said no or have not answered, each with only their name,
 * group name and age band, so a photographer with `photoConsent.read`
 * learns nothing else. Only confirmed people are listed.
 */

export type PhotoAnswer = "no" | "unanswered";

export interface PhotoEntry {
  name: string;
  groupName: string;
  ageBand: string;
  answer: PhotoAnswer;
}

type Data = FirebaseFirestore.DocumentData;

/** [person]'s line on the list, or null when they are not on it. */
export function photoEntry(
  person: Data | undefined,
  details: Data | undefined,
  groupName: string,
  categories: ReadonlyArray<{id?: string; name?: string}>
): PhotoEntry | null {
  if (!person || !isConfirmed(person)) return null;
  const consent = details?.photoConsent;
  if (consent === true) return null;
  return {
    name: String(person.name ?? ""),
    groupName,
    ageBand: String(categories.find((c) => c.id === person.categoryId)?.name ?? ""),
    answer: consent === false ? "no" : "unanswered",
  };
}

const CHUNK = 300;

/** The whole list worked out again from every person in the event. */
export async function rebuildPhotoConsent(db: Firestore, eventId: string): Promise<void> {
  const eventRef = db.collection("events").doc(eventId);
  const [event, people, groups] = await Promise.all([
    eventRef.get(),
    eventRef.collection("participants").get(),
    eventRef.collection("groups").get(),
  ]);
  if (!event.exists) return;
  const categories = event.data()?.settings?.categories ?? [];
  const groupNames = new Map(groups.docs.map((g) => [g.id, String(g.data().name ?? "")]));
  const entries: Record<string, PhotoEntry> = {};
  for (let i = 0; i < people.docs.length; i += CHUNK) {
    const slice = people.docs.slice(i, i + CHUNK);
    const details = await db.getAll(...slice.map((d) => d.ref.collection("private").doc("details")));
    slice.forEach((d, j) => {
      const entry = photoEntry(d.data(), details[j].data(), groupNames.get(d.data().groupId) ?? "", categories);
      if (entry) entries[d.id] = entry;
    });
  }
  await eventRef.collection("photoConsent").doc("current").set({
    people: entries, updatedAt: FieldValue.serverTimestamp(),
  });
}

/**
 * Brings [participantIds]' lines up to date, or builds the whole list when
 * it does not exist yet, so people who never answered are on it.
 */
export async function refreshPhotoConsent(db: Firestore, eventId: string, participantIds: string[]): Promise<void> {
  const eventRef = db.collection("events").doc(eventId);
  const listRef = eventRef.collection("photoConsent").doc("current");
  const [event, list] = await Promise.all([eventRef.get(), listRef.get()]);
  if (!event.exists) return;
  if (!list.exists) {
    await rebuildPhotoConsent(db, eventId);
    return;
  }
  const categories = event.data()?.settings?.categories ?? [];
  const people: Record<string, PhotoEntry | FieldValue> = {};
  for (const id of participantIds) {
    const ref = eventRef.collection("participants").doc(id);
    const [person, details] = await Promise.all([ref.get(), ref.collection("private").doc("details").get()]);
    const groupId = person.data()?.groupId;
    const groupName = typeof groupId === "string" ?
      String((await eventRef.collection("groups").doc(groupId).get()).data()?.name ?? "") : "";
    people[id] = photoEntry(person.data(), details.data(), groupName, categories) ?? FieldValue.delete();
  }
  await listRef.set({people, updatedAt: FieldValue.serverTimestamp()}, {merge: true});
}

const LISTED = ["name", "groupId", "categoryId", "status", "registrationStatus"];
const changed = (before: Data | undefined, after: Data | undefined, keys: string[]) =>
  !before || !after || keys.some((k) => JSON.stringify(before[k] ?? null) !== JSON.stringify(after[k] ?? null));

/** onPhotoConsentPersonWritten — a person added, removed, renamed, moved or cancelled. */
export const onPhotoConsentPersonWritten = onDocumentWritten(
  "events/{eventId}/participants/{participantId}",
  async (event) => {
    if (!changed(event.data?.before.data(), event.data?.after.data(), LISTED)) return;
    await refreshPhotoConsent(getFirestore(), event.params.eventId, [event.params.participantId]);
  }
);

/** onPhotoConsentAnswerWritten — a person's answer changed, as a guardian may change it. */
export const onPhotoConsentAnswerWritten = onDocumentWritten(
  "events/{eventId}/participants/{participantId}/private/details",
  async (event) => {
    if (!changed(event.data?.before.data(), event.data?.after.data(), ["photoConsent"])) return;
    await refreshPhotoConsent(getFirestore(), event.params.eventId, [event.params.participantId]);
  }
);

/** onPhotoConsentGroupWritten — a group renamed, so its people's lines follow. */
export const onPhotoConsentGroupWritten = onDocumentWritten(
  "events/{eventId}/groups/{groupId}",
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after || before.name === after.name) return;
    const db = getFirestore();
    const people = await db.collection("events").doc(event.params.eventId)
      .collection("participants").where("groupId", "==", event.params.groupId).get();
    if (people.empty) return;
    await refreshPhotoConsent(db, event.params.eventId, people.docs.map((d) => d.id));
  }
);
