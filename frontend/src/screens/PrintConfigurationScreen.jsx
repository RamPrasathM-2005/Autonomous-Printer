// src/screens/PrintConfigurationScreen.jsx
import React, { useState, useEffect } from 'react';
import { View, Text, TextInput, Alert } from 'react-native';
import { useNavigation, useRoute } from '@react-navigation/native';
import Screen            from '../components/layout/Screen';
import Header            from '../components/layout/Header';
import PrimaryButton     from '../components/buttons/PrimaryButton';
import SectionHeader     from '../components/layout/SectionHeader';
import SegmentedControl  from '../components/forms/SegmentedControl';
import StepperInput      from '../components/forms/StepperInput';
import useDocumentStore  from '../store/documentStore';
import useConfigStore    from '../store/configStore';
import { DEFAULT_PRINT_CONFIG, COLOR_MODES, PRINT_SIDES, ORIENTATIONS, PAPER_SIZES } from '../constants/print';
import { validatePageRange } from '../utils/pageRange';
import { Routes }        from '../constants/routes';
import { useTheme }      from '../theme';

export default function PrintConfigurationScreen() {
  const navigation  = useNavigation();
  const route       = useRoute();
  const { colors, typography, spacing, radius } = useTheme();

  const { documentId } = route.params;

  const document    = useDocumentStore((s) => s.getDocumentById(documentId));
  const existingCfg = useConfigStore((s) => s.getConfiguration(documentId));
  const saveConfig  = useConfigStore((s) => s.saveConfiguration);

  const [cfg, setCfg] = useState(() => ({
    ...DEFAULT_PRINT_CONFIG,
    documentId,
    ...(existingCfg || {}),
  }));

  const [pageRangeError, setPageRangeError] = useState(null);

  const update = (key, value) => setCfg((prev) => ({ ...prev, [key]: value }));

  const handleSave = () => {
    if (cfg.pageMode === 'custom') {
      const err = validatePageRange(cfg.customPageRange, document?.pageCount || 999);
      if (err) { setPageRangeError(err); return; }
    }
    setPageRangeError(null);
    saveConfig(documentId, cfg);

    // Navigate to order summary or next document
    navigation.navigate(Routes.ORDER_SUMMARY);
  };

  if (!document) {
    navigation.goBack();
    return null;
  }

  return (
    <View style={{ flex: 1 }}>
      <Header title={document.fileName.length > 20 ? document.fileName.slice(0, 20) + '...' : document.fileName} />
      <Screen scrollable>
        <Text style={[typography.bodySmall, { color: colors.onSurfaceVariant, marginBottom: spacing.md }]}>
          {document.pageCount} pages
        </Text>

        <SectionHeader title="Copies" />
        <StepperInput
          value={cfg.copies}
          min={1}
          max={50}
          onChange={(v) => update('copies', v)}
          label="Number of copies"
        />

        <SectionHeader title="Pages" />
        <SegmentedControl
          options={[{ label: 'All Pages', value: 'all' }, { label: 'Custom Range', value: 'custom' }]}
          selected={cfg.pageMode}
          onSelect={(v) => update('pageMode', v)}
        />
        {cfg.pageMode === 'custom' && (
          <>
            <TextInput
              placeholder="e.g. 1-5, 8, 10-12"
              value={cfg.customPageRange || ''}
              onChangeText={(v) => { update('customPageRange', v); setPageRangeError(null); }}
              style={[{
                borderWidth: 1,
                borderColor: pageRangeError ? colors.error : colors.outline,
                borderRadius: radius.sm,
                padding: 12,
                color: colors.onSurface,
                marginBottom: 4,
              }]}
              placeholderTextColor={colors.onSurfaceVariant}
            />
            {pageRangeError && (
              <Text style={[typography.bodySmall, { color: colors.error, marginBottom: spacing.sm }]}>
                {pageRangeError}
              </Text>
            )}
          </>
        )}

        <SectionHeader title="Color" />
        <SegmentedControl
          options={COLOR_MODES}
          selected={cfg.colorMode}
          onSelect={(v) => update('colorMode', v)}
        />

        <SectionHeader title="Sides" />
        <SegmentedControl
          options={PRINT_SIDES}
          selected={cfg.printSide}
          onSelect={(v) => update('printSide', v)}
        />

        <SectionHeader title="Paper Size" />
        <SegmentedControl
          options={PAPER_SIZES}
          selected={cfg.paperSize}
          onSelect={(v) => update('paperSize', v)}
        />

        <SectionHeader title="Orientation" />
        <SegmentedControl
          options={ORIENTATIONS}
          selected={cfg.orientation}
          onSelect={(v) => update('orientation', v)}
        />

        <View style={{ height: spacing.xl }} />
        <PrimaryButton label="Save & Continue" onPress={handleSave} />
      </Screen>
    </View>
  );
}
