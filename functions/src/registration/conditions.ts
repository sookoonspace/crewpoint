import {FieldCondition} from "./settings";

/**
 * Whether a form question is shown to a person (Spec #233 Req 18; #242):
 * to one category, or when one other answer has a value. Hidden questions
 * are never required and their answers are not saved. Pure, with its cases
 * in `test/fixtures/condition_cases.json`, which the app's
 * `form_conditions.dart` also runs; change them together.
 */
export interface ConditionPerson {
  /** The person's category, or null while it is unknown. */
  categoryId: string | null;
  /** Their answers and their group's, by question ID. */
  answers: Record<string, unknown>;
}

/** An answer as conditions compare it: yes/no as `yes`/`no`. */
function asText(value: unknown): string {
  return typeof value === "boolean" ? (value ? "yes" : "no") : String(value);
}

export function isShown(condition: FieldCondition | null | undefined, person: ConditionPerson): boolean {
  if (!condition) return true;
  if ("categoryId" in condition) return person.categoryId === condition.categoryId;
  const answer = person.answers[condition.fieldId];
  if (answer === undefined || answer === null) return false;
  if (Array.isArray(answer)) return answer.some((a) => asText(a) === condition.value);
  return asText(answer) === condition.value;
}
