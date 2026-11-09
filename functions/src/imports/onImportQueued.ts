import {onDocumentWritten} from "firebase-functions/v2/firestore";
import {getStorage} from "firebase-admin/storage";
import {runImportJob} from "./runImport";

/**
 * onImportQueued — runs an import job when it is queued (Req 44a, 75), as a
 * check or an apply. Runs on the server, so the person can leave and come
 * back to the job's report.
 */
export const onImportQueued = onDocumentWritten(
  {document: "events/{eventId}/imports/{jobId}", timeoutSeconds: 540, memory: "512MiB"},
  async (event) => {
    const after = event.data?.after.data();
    const before = event.data?.before.data();
    if (after?.status !== "queued" || before?.status === "queued") return;
    const bucket = getStorage().bucket();
    await runImportJob({
      eventId: event.params.eventId,
      jobId: event.params.jobId,
      readFile: async (path) => (await bucket.file(path).download())[0].toString("utf8"),
      deleteFile: async (path) => {
        await bucket.file(path).delete({ignoreNotFound: true});
      },
    });
  }
);
