export const getRelativeTimeString = (date, language = 'en') => {
  console.log(language)
  const rtf = new Intl.RelativeTimeFormat(language, { numeric: 'auto' });
  const now = new Date();
  const diffInMs = date - now;
  const diffInDays = Math.round(diffInMs / (1000 * 60 * 60 * 24));
  const diffInHours = Math.round(diffInMs / (1000 * 60 * 60));
  const diffInMinutes = Math.round(diffInMs / (1000 * 60));

  if (Math.abs(diffInMinutes) < 60) return rtf.format(diffInMinutes, 'minute');
  if (Math.abs(diffInHours) < 24) return rtf.format(diffInHours, 'hour');
  return rtf.format(diffInDays, 'day');
};