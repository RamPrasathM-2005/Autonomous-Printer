// src/screens/UploadScreen.jsx
import React, { useState } from 'react';
import { View, Text, FlatList, StyleSheet, Alert } from 'react-native';
import { useNavigation }    from '@react-navigation/native';
import DocumentPicker, { types } from 'react-native-document-picker';
import Screen               from '../components/layout/Screen';
import Header               from '../components/layout/Header';
import PrimaryButton        from '../components/buttons/PrimaryButton';
import SecondaryButton      from '../components/buttons/SecondaryButton';
import UploadProgress       from '../components/feedback/UploadProgress';
import EmptyState           from '../components/feedback/EmptyState';
import { useDocumentUpload }from '../hooks/useDocumentUpload';
import { Routes }           from '../constants/routes';
import { useTheme }         from '../theme';
import { MAX_FILE_COUNT }   from '../constants/files';

let _localId = 0;
const nextId = () => `local_${++_localId}`;

export default function UploadScreen() {
  const navigation  = useNavigation();
  const { colors, typography, spacing } = useTheme();

  const {
    selectedFiles, addFiles, removeFile,
    uploadProgresses, uploadErrors,
    isUploading, uploadAll,
  } = useDocumentUpload();

  const pickFiles = async () => {
    try {
      const picked = await DocumentPicker.pick({
        allowMultiSelection: true,
        type: [types.pdf, types.docx, types.pptx, types.images],
      });

      const withIds = picked.map((f) => ({ ...f, localId: nextId() }));
      const result  = addFiles(withIds);
      if (result.error) Alert.alert('Cannot add files', result.error);
    } catch (err) {
      if (!DocumentPicker.isCancel(err)) {
        Alert.alert('Error', 'Could not open file picker.');
      }
    }
  };

  const handleUpload = async () => {
    const { success } = await uploadAll();
    if (success) navigation.navigate(Routes.UPLOADED_DOCUMENTS);
  };

  const statusOf = (file) => {
    if (uploadErrors[file.localId]) return 'error';
    if (uploadProgresses[file.localId] === 100) return 'success';
    if (file.localId in uploadProgresses) return 'uploading';
    return 'pending';
  };

  return (
    <View style={{ flex: 1 }}>
      <Header title="Upload Files" />
      <Screen scrollable={false}>
        {selectedFiles.length === 0 ? (
          <EmptyState
            title="No files selected"
            description={`Add up to ${MAX_FILE_COUNT} files (PDF, DOCX, PPTX, PNG, JPG · max 20 MB each)`}
            actionLabel="Select Files"
            onAction={pickFiles}
          />
        ) : (
          <FlatList
            data={selectedFiles}
            keyExtractor={(item) => item.localId}
            renderItem={({ item }) => (
              <UploadProgress
                fileName={item.name}
                progress={uploadProgresses[item.localId] ?? 0}
                status={statusOf(item)}
                errorMessage={uploadErrors[item.localId]}
              />
            )}
            contentContainerStyle={{ gap: 8 }}
          />
        )}

        {selectedFiles.length > 0 && (
          <View style={styles.footer}>
            <SecondaryButton
              label="Add More"
              onPress={pickFiles}
              disabled={isUploading || selectedFiles.length >= MAX_FILE_COUNT}
              fullWidth={false}
              style={{ flex: 1 }}
            />
            <PrimaryButton
              label={isUploading ? 'Uploading...' : 'Upload All'}
              loading={isUploading}
              onPress={handleUpload}
              disabled={isUploading}
              fullWidth={false}
              style={{ flex: 1 }}
            />
          </View>
        )}
      </Screen>
    </View>
  );
}

const styles = StyleSheet.create({
  footer: { flexDirection: 'row', gap: 12, paddingTop: 16 },
});
