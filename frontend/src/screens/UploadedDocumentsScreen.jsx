// src/screens/UploadedDocumentsScreen.jsx
import React, { useState } from 'react';
import { View, FlatList, Alert } from 'react-native';
import { useNavigation }     from '@react-navigation/native';
import Screen                from '../components/layout/Screen';
import Header                from '../components/layout/Header';
import PrimaryButton         from '../components/buttons/PrimaryButton';
import SecondaryButton       from '../components/buttons/SecondaryButton';
import DocumentCard          from '../components/cards/DocumentCard';
import EmptyState            from '../components/feedback/EmptyState';
import Dialog                from '../components/overlays/Dialog';
import useDocumentStore      from '../store/documentStore';
import useConfigStore        from '../store/configStore';
import { documentsApi }      from '../services/api/documents';
import { Routes }            from '../constants/routes';
import { useTheme }          from '../theme';

export default function UploadedDocumentsScreen() {
  const navigation  = useNavigation();
  const { spacing } = useTheme();

  const documents        = useDocumentStore((s) => s.documents);
  const removeDocument   = useDocumentStore((s) => s.removeDocument);
  const removeConfig     = useConfigStore((s) => s.removeConfiguration);

  const [deletingId, setDeletingId]     = useState(null);
  const [confirmId, setConfirmId]       = useState(null); // show delete dialog

  const handleEdit = (documentId) => {
    navigation.navigate(Routes.PRINT_CONFIGURATION, { documentId });
  };

  const handleDeleteConfirm = async () => {
    const id = confirmId;
    setConfirmId(null);
    setDeletingId(id);
    try {
      await documentsApi.delete(id);
      removeDocument(id);
      removeConfig(id);
    } catch {
      Alert.alert('Delete failed', 'Could not remove this document. Try again.');
    } finally {
      setDeletingId(null);
    }
  };

  return (
    <View style={{ flex: 1 }}>
      <Header title="Your Documents" />
      <Screen scrollable={false}>
        {documents.length === 0 ? (
          <EmptyState
            title="No documents"
            description="All documents were removed. Go back to upload again."
            actionLabel="Go Back"
            onAction={() => navigation.navigate(Routes.UPLOAD)}
          />
        ) : (
          <FlatList
            data={documents}
            keyExtractor={(d) => d.documentId}
            renderItem={({ item }) => (
              <DocumentCard
                document={item}
                onEdit={handleEdit}
                onDelete={(id) => setConfirmId(id)}
                isDeleting={deletingId === item.documentId}
              />
            )}
            contentContainerStyle={{ paddingBottom: 80 }}
          />
        )}

        {documents.length > 0 && (
          <View style={{ paddingTop: spacing.md, gap: 8 }}>
            <SecondaryButton
              label="Add More Files"
              onPress={() => navigation.navigate(Routes.UPLOAD)}
            />
            <PrimaryButton
              label="Continue to Print Config"
              onPress={() => navigation.navigate(Routes.PRINT_CONFIGURATION, { documentId: documents[0].documentId })}
            />
          </View>
        )}
      </Screen>

      <Dialog
        visible={!!confirmId}
        title="Remove Document"
        message="This document will be removed from your session. This cannot be undone."
        confirmLabel="Remove"
        cancelLabel="Keep"
        dangerous
        onConfirm={handleDeleteConfirm}
        onCancel={() => setConfirmId(null)}
      />
    </View>
  );
}
