"""Contacts service with direct Google People API integration."""
from __future__ import annotations

import logging
from typing import Any

from googleapiclient.discovery import build

from app.config import Settings
from app.core.google_auth import get_google_credentials
from app.schemas.contacts_schema import ContactFindRequest, ContactUpsertRequest

logger = logging.getLogger("sira_api_v3.services.contacts")


class ContactsServiceImpl:
    """Direct Google People API integration."""

    def __init__(self, settings: Settings) -> None:
        self._settings = settings
        self._service = None

    def _get_service(self):
        """Lazy-load People API service."""
        if not self._service:
            creds = get_google_credentials(self._settings)
            self._service = build("people", "v1", credentials=creds)
        return self._service

    async def find_contact(self, request: ContactFindRequest) -> dict[str, Any]:
        """Search contacts."""
        service = self._get_service()

        result = (
            service.people()
            .searchContacts(query=request.query, readMask="names,emailAddresses,phoneNumbers,organizations")
            .execute()
        )

        contacts = []
        for person in result.get("results", [])[:request.limit]:
            p = person.get("person", {})
            name = p.get("names", [{}])[0].get("displayName", "")
            email = p.get("emailAddresses", [{}])[0].get("value", "")
            phone = p.get("phoneNumbers", [{}])[0].get("value", "")
            company = p.get("organizations", [{}])[0].get("name", "")

            contacts.append(
                {
                    "resourceName": p.get("resourceName"),
                    "name": name,
                    "email": email,
                    "phone": phone,
                    "company": company,
                }
            )

        logger.info("Contacts found", extra={"count": len(contacts)})
        return {"ok": True, "count": len(contacts), "results": contacts}

    async def upsert_contact(self, request: ContactUpsertRequest) -> dict[str, Any]:
        """Create or update contact."""
        service = self._get_service()

        # Search for existing contact by email
        search_result = (
            service.people()
            .searchContacts(query=request.email, readMask="names,emailAddresses")
            .execute()
        )

        person_body = {
            "emailAddresses": [{"value": request.email}],
        }

        if request.first_name or request.last_name:
            person_body["names"] = [
                {
                    "givenName": request.first_name or "",
                    "familyName": request.last_name or "",
                }
            ]

        if request.phone:
            person_body["phoneNumbers"] = [{"value": request.phone}]

        if request.company:
            person_body["organizations"] = [{"name": request.company}]

        if search_result.get("results"):
            # Update existing
            resource_name = search_result["results"][0]["person"]["resourceName"]
            result = (
                service.people()
                .updateContact(
                    resourceName=resource_name,
                    updatePersonFields="names,emailAddresses,phoneNumbers,organizations",
                    body=person_body,
                )
                .execute()
            )
            logger.info("Contact updated", extra={"resource_name": resource_name})
            return {"ok": True, "action": "updated", "resourceName": result["resourceName"]}
        else:
            # Create new
            result = service.people().createContact(body=person_body).execute()
            logger.info("Contact created", extra={"resource_name": result["resourceName"]})
            return {"ok": True, "action": "created", "resourceName": result["resourceName"]}
