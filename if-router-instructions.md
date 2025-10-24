# IF-Router Installation Instructions

## Wichtig
Das komplette JSON ist zu groß. Du musst die IF-Chain manuell in n8n einbauen.

## Schritt 1: Route Node deaktivieren
1. Klicke auf den "Route" Node
2. Rechtsklick → "Deactivate"
3. NICHT löschen (als Backup behalten)

## Schritt 2: IF-Chain aufbauen

### Gruppe 1: Calendar
```
Validate Input → IF calendar.* ({{$json.tool && $json.tool.startsWith('calendar.')}})
  ├─ true → IF calendar.list ({{$json.tool}} equals "calendar.list")
  │   ├─ true → Prep Cal List
  │   └─ false → IF calendar.create ({{$json.tool}} equals "calendar.create")
  │       ├─ true → Prep Cal Create
  │       └─ false → IF calendar.update ({{$json.tool}} equals "calendar.update")
  │           ├─ true → Prep Cal Update
  │           └─ false → IF calendar.free_slots ({{$json.tool}} equals "calendar.free_slots")
  │               ├─ true → Prep Cal Free
  │               └─ false → nächste Gruppe
  └─ false → IF gmail.*
```

### Gruppe 2: Gmail
```
IF gmail.* ({{$json.tool && $json.tool.startsWith('gmail.')}})
  ├─ true → IF gmail.send ({{$json.tool}} equals "gmail.send")
  │   ├─ true → Prep Gmail Send
  │   └─ false → IF gmail.reply ({{$json.tool}} equals "gmail.reply")
  │       ├─ true → Prep Gmail Reply
  │       └─ false → IF gmail.get ({{$json.tool}} equals "gmail.get")
  │           ├─ true → Prep Gmail Get
  │           └─ false → nächste Gruppe
  └─ false → IF contacts.*
```

### Gruppe 3: Contacts
```
IF contacts.* ({{$json.tool && $json.tool.startsWith('contacts.')}})
  ├─ true → IF contacts.find ({{$json.tool}} equals "contacts.find")
  │   ├─ true → Prep Contacts Find
  │   └─ false → IF contacts.upsert ({{$json.tool}} equals "contacts.upsert")
  │       ├─ true → Prep Contacts Upsert
  │       └─ false → nächste Gruppe
  └─ false → IF web.*
```

### Gruppe 4: Web
```
IF web.* ({{$json.tool && $json.tool.startsWith('web.')}})
  ├─ true → IF web.search ({{$json.tool}} equals "web.search")
  │   ├─ true → Prep Web Search
  │   └─ false → IF web.fetch ({{$json.tool}} equals "web.fetch")
  │       ├─ true → Prep Web Fetch
  │       └─ false → Others
  └─ false → IF notes.log
```

### Others (einzeln)
```
IF notes.log ({{$json.tool}} equals "notes.log")
  ├─ true → Prep Notes
  └─ false → IF weather.get ({{$json.tool}} equals "weather.get")
      ├─ true → Prep Weather
      └─ false → IF news.get ({{$json.tool}} equals "news.get")
          ├─ true → Prep News
          └─ false → IF perplexity.search ({{$json.tool}} equals "perplexity.search")
              ├─ true → Prep Perplexity
              └─ false → IF reminder.set ({{$json.tool}} equals "reminder.set")
                  ├─ true → Prep Reminder
                  └─ false → Error Response
```

## Conditions für Copy&Paste

### Gruppen-IFs (Boolean "is true")
- Calendar: `{{$json.tool && $json.tool.startsWith('calendar.')}}`
- Gmail: `{{$json.tool && $json.tool.startsWith('gmail.')}}`
- Contacts: `{{$json.tool && $json.tool.startsWith('contacts.')}}`
- Web: `{{$json.tool && $json.tool.startsWith('web.')}}`

### Einzel-IFs (String "equals")
- Left: `{{$json.tool}}`
- Operation: equals
- Right: Der jeweilige Tool-Name (z.B. `calendar.list`)

## Test nach Installation

1. **calendar.list**: "Habe ich morgen Termine?"
   - Erwartung: IF calendar.* → IF calendar.list → Prep Cal List → Cal List → Respond

2. **notes.log**: "Notiere: Test erfolgreich"
   - Erwartung: IF notes.log → Prep Notes → Sheets Append → Respond

3. **weather.get**: "Wie ist das Wetter?"
   - Erwartung: IF weather.get → Prep Weather → Shape Weather → Respond

4. **gmail.send**: "Sende eine Email an test@test.com"
   - Erwartung: IF gmail.* → IF gmail.send → Prep Gmail Send → Gmail Send → Respond

## Wichtige Hinweise
- Jeder IF hat nur EINE Condition
- true geht zum Ziel-Node oder nächsten IF in der Gruppe
- false geht zur nächsten Gruppe oder zum nächsten Einzel-IF
- Am Ende: false → Error Response (Fallback)
