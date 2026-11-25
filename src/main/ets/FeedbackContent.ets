export function feedbackContent(content: string, metadata: Record<string, string>): string {
  let text = content.trim();
  if (text.length === 0) {
    throw new Error('Feedback must not be empty');
  }
  const keys = Object.keys(metadata).sort();
  if (keys.length > 0) {
    text += '\n\n' + keys.map((key: string) => key + ': ' + metadata[key]).join('\n');
  }
  if (Array.from(text).length > 2000) {
    throw new Error('Feedback including metadata must not exceed 2000 characters');
  }
  return text;
}
