export const INDONESIA_BOUNDS = {
  minLatitude: -11.2,
  maxLatitude: 6.3,
  minLongitude: 94.5,
  maxLongitude: 141.1,
} as const;

export function isInIndonesia(latitude: number, longitude: number) {
  return (
    latitude >= INDONESIA_BOUNDS.minLatitude &&
    latitude <= INDONESIA_BOUNDS.maxLatitude &&
    longitude >= INDONESIA_BOUNDS.minLongitude &&
    longitude <= INDONESIA_BOUNDS.maxLongitude
  );
}
