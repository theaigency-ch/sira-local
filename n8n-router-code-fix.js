// NEUER ROUTER CODE FÜR n8n
// Ersetze den Switch Node mit einem Code Node

const tool = $json.tool;

if (!tool) {
  throw new Error('Missing tool parameter');
}

// Route to correct output based on tool
const routes = {
  'gmail.send': 0,
  'gmail.reply': 1,
  'gmail.get': 2,
  'calendar.free_slots': 3,
  'calendar.create': 4,
  'calendar.update': 5,
  'calendar.list': 6,
  'contacts.find': 7,
  'contacts.upsert': 8,
  'web.search': 9,
  'web.fetch': 10,
  'perplexity.search': 11,
  'news.get': 12,
  'weather.get': 13,
  'notes.log': 14,
  'reminder.set': 15
};

const outputIndex = routes[tool];

if (outputIndex === undefined) {
  // Fallback
  return [{json: {...$json, error: `Unknown tool: ${tool}`}}];
}

// Create outputs array with empty arrays for all outputs
const outputs = Array(16).fill(null).map(() => []);

// Put the data in the correct output
outputs[outputIndex] = [{json: $json}];

return outputs;
