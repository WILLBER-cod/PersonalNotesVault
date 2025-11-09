from rest_framework import serializers
from .models import Note
from .services import encrypt_note, decrypt_note


class NoteSerializer(serializers.ModelSerializer):
    title = serializers.CharField(write_only=True, required=False, allow_blank=True)
    content = serializers.CharField(write_only=True, required=False, allow_blank=True)

    class Meta:
        model = Note
        fields = ('id', 'title', 'content', 'title_encrypted', 'content_encrypted', 'created_at', 'updated_at')
        read_only_fields = ('id', 'title_encrypted', 'content_encrypted', 'created_at', 'updated_at')

    def create(self, validated_data):
        title = validated_data.pop('title', '')
        content = validated_data.pop('content', '')
        user = self.context['request'].user

        title_encrypted, content_encrypted = encrypt_note(title, content)

        note = Note.objects.create(
            user=user,
            title_encrypted=title_encrypted,
            content_encrypted=content_encrypted,
        )
        return note

    def update(self, instance, validated_data):
        title = validated_data.pop('title', None)
        content = validated_data.pop('content', None)

        if title is not None:
            title_encrypted, _ = encrypt_note(title, '')
            instance.title_encrypted = title_encrypted

        if content is not None:
            _, content_encrypted = encrypt_note('', content)
            instance.content_encrypted = content_encrypted

        instance.save()
        return instance

    def to_representation(self, instance):
        representation = super().to_representation(instance)
        title, content = decrypt_note(instance.title_encrypted, instance.content_encrypted)
        representation['title'] = title
        representation['content'] = content
        representation.pop('title_encrypted', None)
        representation.pop('content_encrypted', None)
        return representation
