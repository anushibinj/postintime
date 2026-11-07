/** Caption followed by the account's footer after a blank line; the footer arrives platform-formatted. */
export function withFooter(caption?: string, footer?: string): string {
  const base = caption || '';
  if (!footer) return base;
  return base.trim() === '' ? footer : `${base}\n\n${footer}`;
}
