export const DEFAULT_PAGE_SIZE = 20;
export const MAX_PAGE_SIZE = 100;
export const PAGE_SIZE_OPTIONS = [10, 20, 50];

export function parsePageParam(value: string | null): number {
  const page = Number(value);
  if (!Number.isInteger(page) || page < 0) {
    return 0;
  }
  return page;
}

export function parseSizeParam(value: string | null): number {
  const size = Number(value);
  if (!Number.isInteger(size) || size < 1 || size > MAX_PAGE_SIZE) {
    return DEFAULT_PAGE_SIZE;
  }
  return size;
}
