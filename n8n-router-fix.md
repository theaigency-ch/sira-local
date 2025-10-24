# n8n Router Fix Instructions

## Problem
Der Router matched `calendar.list` korrekt, sendet es aber zum falschen Output (gmail.send).

## Lösung 1: Manuelle Fix in n8n

1. Öffne den **Route** Node
2. Scrolle zur Rule #14 (calendar.list)
3. **WICHTIG:** Notiere dir die genaue Condition
4. Lösche die calendar.list Rule
5. Klicke "Add Routing Rule" (ganz oben)
6. Erstelle neue Rule:
   - Condition: `{{ $json.tool }}` equals `calendar.list`
   - Output Name: `calendar.list`
7. Speichern und Workflow aktivieren

## Lösung 2: Router komplett neu

Falls Lösung 1 nicht funktioniert:

1. Lösche den Route Node
2. Erstelle neuen Switch Node
3. Füge alle Rules in DIESER Reihenfolge hinzu:
   - calendar.list (ERSTE!)
   - gmail.send
   - gmail.reply
   - gmail.get
   - ... (rest)

## Test
Nach dem Fix:
1. Neue Execution starten
2. Router Output prüfen
3. calendar.list Tab sollte GRÜN sein
4. Daten sollten zu Cal List Node gehen
