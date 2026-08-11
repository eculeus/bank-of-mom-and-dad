export function dollars(cents) {
  const abs = Math.abs(cents) / 100;
  return `$${abs.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
}

export const kidTransactionCopy = (amountCents) =>
  amountCents >= 0
    ? `You received a new deposit of ${dollars(amountCents)} in your account!`
    : `A deduction of ${dollars(amountCents)} was made from your account.`;

export const requestApprovedCopy = (amountCents) =>
  `Your request for ${dollars(amountCents)} was approved and added to your account!`;

export const requestDeniedCopy = (amountCents, parentName) =>
  `Your request for ${dollars(amountCents)} was denied — please talk to ${parentName}.`;

export const newRequestCopy = (kidName) => `New transaction request from ${kidName}`;

export const parentTransactionCopy = (parentName, kidName, amountCents, reason, eventType) => {
  if (eventType === 'update') return `${parentName} edited a transaction for ${kidName}`;
  if (eventType === 'delete') return `${parentName} deleted a transaction for ${kidName}`;
  return amountCents >= 0
    ? `${parentName} added ${dollars(amountCents)} to ${kidName}: ${reason}`
    : `${parentName} deducted ${dollars(amountCents)} from ${kidName}: ${reason}`;
};

export const kidDeletedCopy = (kidName) => `${kidName} deleted their Bank of Mom and Dad account.`;

export const recurringDueCopy = (kidName, amountCents, reason) =>
  amountCents >= 0
    ? `Recurring due for ${kidName}: ${reason} (+${dollars(amountCents)})`
    : `Recurring due for ${kidName}: ${reason} (−${dollars(amountCents)})`;
