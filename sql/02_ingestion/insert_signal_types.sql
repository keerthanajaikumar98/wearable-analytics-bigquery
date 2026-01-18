-- Insert signal type definitions
INSERT INTO `wearable_analytics.dim_signal_types` 
  (signal_type, signal_name, unit, sample_rate_hz, normal_range_min, normal_range_max, description)
VALUES
  ('BVP', 'Blood Volume Pulse', 'unitless', 64.0, NULL, NULL, 'Photoplethysmography signal'),
  ('EDA', 'Electrodermal Activity', 'microsiemens', 4.0, 0.01, 25.0, 'Skin conductance'),
  ('TEMP', 'Skin Temperature', 'celsius', 4.0, 20.0, 40.0, 'Peripheral temperature'),
  ('ACC_X', 'Acceleration X-axis', 'g', 32.0, -2.0, 2.0, '3-axis accelerometer X'),
  ('ACC_Y', 'Acceleration Y-axis', 'g', 32.0, -2.0, 2.0, '3-axis accelerometer Y'),
  ('ACC_Z', 'Acceleration Z-axis', 'g', 32.0, -2.0, 2.0, '3-axis accelerometer Z'),
  ('HR', 'Heart Rate', 'bpm', 1.0, 40.0, 200.0, 'Derived from BVP'),
  ('IBI', 'Inter-Beat Interval', 'seconds', NULL, 0.3, 2.0, 'Time between heartbeats');