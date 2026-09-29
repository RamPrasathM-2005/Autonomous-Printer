// src/components/status/StatusTimeline.jsx
import React from 'react';
import { View } from 'react-native';
import StatusStep from './StatusStep';

/**
 * @param {{ steps: Array<{ label: string, status: 'completed'|'active'|'pending' }> }} props
 */
export default function StatusTimeline({ steps }) {
  return (
    <View>
      {steps.map((step, idx) => (
        <StatusStep
          key={step.label}
          label={step.label}
          status={step.status}
          isLast={idx === steps.length - 1}
        />
      ))}
    </View>
  );
}
