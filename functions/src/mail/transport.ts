/**
 * How an email leaves CrewPoint (Spec #233 Technical Decision 6). The send
 * function talks only to this interface: Resend in deployed projects, the
 * mock in tests, and a transport that refuses everything under the
 * emulators or a `demo-` project, so no automated run can send real email.
 */
export interface OutgoingEmail {
  from: string;
  to: string;
  subject: string;
  text: string;
  html: string;
  /** Sent as the provider's idempotency key, so a retry never sends twice. */
  messageId: string;
}

export interface EmailTransport {
  /** Returns the provider's message ID. Throws when the provider refuses. */
  send(email: OutgoingEmail): Promise<{providerId: string}>;
}

export class TransportRefused extends Error {}

/** Resend's HTTP API (https://resend.com/docs/api-reference/emails). */
export class ResendTransport implements EmailTransport {
  constructor(
    private readonly apiKey: string,
    private readonly fetchFn: typeof fetch = fetch,
  ) {}

  async send(email: OutgoingEmail): Promise<{providerId: string}> {
    const response = await this.fetchFn("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${this.apiKey}`,
        "Content-Type": "application/json",
        "Idempotency-Key": email.messageId,
      },
      body: JSON.stringify({
        from: email.from,
        to: [email.to],
        subject: email.subject,
        text: email.text,
        html: email.html,
      }),
    });
    const body = await response.json().catch(() => ({})) as {id?: string; message?: string};
    if (!response.ok || typeof body.id !== "string") {
      throw new Error(`Resend refused the email (${response.status}): ${body.message ?? "no message"}`);
    }
    return {providerId: body.id};
  }
}

/** Records emails instead of sending them. Used by tests. */
export class MockTransport implements EmailTransport {
  readonly sent: OutgoingEmail[] = [];
  failWith: Error | null = null;

  async send(email: OutgoingEmail): Promise<{providerId: string}> {
    if (this.failWith) throw this.failWith;
    this.sent.push(email);
    return {providerId: `mock-${this.sent.length}`};
  }
}

/** Sends nothing. The default under the emulators and `demo-` projects. */
export class RefusingTransport implements EmailTransport {
  async send(): Promise<{providerId: string}> {
    throw new TransportRefused("Real email is never sent from emulators or demo projects");
  }
}

/** True when running under the emulators or a `demo-` project. */
export function isTestEnvironment(env: NodeJS.ProcessEnv = process.env): boolean {
  const project = env.GCLOUD_PROJECT ?? env.GCP_PROJECT ?? "";
  return env.FUNCTIONS_EMULATOR === "true" ||
    Boolean(env.FIRESTORE_EMULATOR_HOST) ||
    project.startsWith("demo-") ||
    project === "";
}
