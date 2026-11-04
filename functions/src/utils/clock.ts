/** The current time, as a seam so tests can control it. */
export const clock = {
  now: (): number => Date.now(),
};
