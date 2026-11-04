import defaults from "../shared/label_defaults.json";

type Concept = keyof typeof defaults;
type Form = "one" | "other";

function custom(label: unknown, form: Form): string | null {
  if (typeof label !== "object" || label === null) return null;
  const text = (label as Record<string, unknown>)[form];
  return typeof text === "string" && text.trim().length > 0 ? text.trim() : null;
}

/**
 * An event's word for a concept, or the default from the file the app also
 * reads (Req 20). Used for message text, so it matches what screens show.
 */
export function resolveLabel(
  labels: Record<string, unknown> | undefined,
  concept: Concept,
  form: Form
): string {
  const label = labels?.[concept];
  const otherForm: Form = form === "one" ? "other" : "one";
  return custom(label, form) ?? custom(label, otherForm) ?? defaults[concept][form];
}
