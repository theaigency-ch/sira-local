# Business & Firma

the aigency bietet KI-Agenten-Entwicklung, Automatisierung via n8n, Prozessberatung und Content-Automation mit GPT-Integration

Unsere Hauptkunden sind Schweizer KMU im Dienstleistungsbereich, Makler, Anwälte, Treuhänder und Architekten

Unser USP ist die Kombination aus Schweizer Datenschutzstandards, persönlicher KI-Assistentin Sira und modularem Aufbau von Beratung bis Integration

Typische Projekte sind automatisiertes E-Mail-Handling via GPT, Google-Kalender-Integration mit Terminbuchung und KI-basierte Dokumenten-Recherche mit RAG

Das Sira Startpaket dauert 3 Wochen, beinhaltet Discovery Workshop, 2 Automationen und Prompt-Set für CHF 4800 netto

# Tech Stack & Tools

Wir nutzen Coolify für Deployment und Docker Compose für die Infrastruktur auf Hostinger VPS mit Ubuntu 24.04 LTS

Wir setzen n8n als Automatisierungs-Layer ein mit Workflows für Gmail, Kalender, Web-Suche und RAG

Wir arbeiten mit GPT-4o via OpenAI API, OpenAI Embeddings für RAG und Qdrant als Vektor-Datenbank

Wir nutzen ElevenLabs für Text-to-Speech mit Voice ID Doreen Pelz

Wir verwenden Redis für Session-Management und Caching

Cloudflare Tunnels verbinden n8n.theaigency.ch und sira.theaigency.ch mit unserem Server

# n8n Workflows & Intents

Der zentrale Webhook ist Sira3-tasks-create und routet nach Tool wie gmail, web, calendar oder contacts

gmail.send sendet neue Mails, gmail.reply antwortet in Threads

calendar.free_slots prüft freie Zeiten, calendar.create erstellt Termine, calendar.update ändert bestehende Termine

web.search nutzt SerpAPI, web.fetch ruft Webseiteninhalte ab

contacts.find durchsucht Google Contacts, contacts.upsert erstellt oder aktualisiert Kontakte

notes.log schreibt Gesprächsnotizen in Google Sheet

rag.query sucht nach passendem Dokument aus Pinecone, rag.ingest fügt neues Wissen mit OpenAI Embeddings hinzu

# Marketing & Positionierung

Wir nutzen primär LinkedIn für persönliches Branding von Peter Baka mit Education-First Strategie und Fallstudien

Die Website theaigency.ch ist unsere zentrale Landingpage auf WordPress

Unsere Positionierung ist High-End Agentur für KI und Automatisierung mit Fokus auf persönliche KI-Assistenten

# Schweiz-spezifisches Wissen

Schweizer Kunden bevorzugen Datenschutz-konforme, lokal betriebene Lösungen auf CH-Servern

Das Schweizer Datenschutzgesetz revDSG ist seit 2023 verbindlich

Schweizer Kunden erwarten verlässliche Technik ohne Beta-Experimente im Livebetrieb

Remote-Setup ist wichtig, aber persönliche Erreichbarkeit zählt

# Kommunikationsstil

Die Ansprache ist Du bei KMU und Coaches, Sie bei Firmenkunden

Der Stil ist klar, lösungsorientiert, ohne Jargon, mit leichter Ironie wenn hilfreich

Wir verwenden keine Floskeln, Übertreibungen oder Clickbait und fantasieren nicht

# Team & Rollen

Peter Baka ist Agenturleitung und zuständig für Strategie, DevOps und Sales

Sira ist die virtuelle Assistentin für Kommunikation, Tasks und Voice UI

Stefanie Steiner ist Projektassistenz für Kundenkommunikation und Organisation

# Aktuelle KI-Trends 2024-2025

GPT-4o bietet multimodale Fähigkeiten mit Voice und Vision

Claude 3.5 von Anthropic ist sicher und dialogorientiert mit langen Kontexten

Mistral ist Open-Source und ermöglicht günstigen lokalen Betrieb

Multimodale Agenten kombinieren Text, Audio und Bild in Echtzeit

Agentic AI mit CrewAI, AutoGen und LangGraph orchestriert komplexe Aufgaben autonom

RAG mit Retrieval-Augmented Generation ist Standard für Wissensabfragen

# Markt Schweiz

Der Schweizer KI-Markt hat ein Volumen von ca. USD 200 Mio in 2024 mit 21.2% CAGR bis 2033

Treibende Sektoren sind Dienstleistungen, Medien und Finanzen

Herausforderungen sind Zurückhaltung bei KI-Adoption, Datenschutzbedenken und Fachkräftemangel

Chancen liegen in Branchenfokus, Kombination von Beratung und Umsetzung sowie wiederverwendbaren Modulen

# Technische Infrastruktur

Der Hostinger VPS läuft auf Ubuntu 24.04 LTS mit 16 GB RAM

Container laufen via Docker Compose für n8n, SiraNet, Redis und Qdrant

DevOps nutzt lokale Builds mit Windsurf und Golden-Freeze via Tagging

Health-Checks laufen auf /healthz Endpoints

# Deployment & Multimodalität

Text-to-Video Tools sind LTX Studio, RunwayML und Pika

Text-to-Image Tools sind DALL-E 3, Midjourney und Nano Banana

Audio-to-Text und Voice Cloning nutzen ElevenLabs und OpenAI Voice

Deployment-Plattformen sind Coolify, Modal, Replicate und Hugging Face Spaces
