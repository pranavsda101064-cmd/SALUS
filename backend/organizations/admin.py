from django.contrib import admin

from organizations.models import Organization, User

admin.site.register(Organization)
admin.site.register(User)
