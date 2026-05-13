/// GATT UUIDs and defaults for the Nexus necklace (no Flutter / BLE SDK).
class BleConstants {
  static const String defaultDeviceName = "Nexus-Audio";
  static const String serviceUuid = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  static const String audioTxCharacteristicUuid =
      "beb5483e-36e1-4688-b7f5-ea07361b26a8";
  static const String audioRxCharacteristicUuid =
      "beb5483e-36e1-4688-b7f5-ea07361b26a9";
  static const String batteryCharacteristicUuid =
      "beb5483e-36e1-4688-b7f5-ea07361b26aa";
  static const String hapticCharacteristicUuid =
      "beb5483e-36e1-4688-b7f5-ea07361b26ac";
  static const String rtcCharacteristicUuid =
      "beb5483e-36e1-4688-b7f5-ea07361b26ab";
  static const String deviceNameCharacteristicUuid =
      "beb5483e-36e1-4688-b7f5-ea07361b26ad";
  static const String fileTxCharacteristicUuid =
      "beb5483e-36e1-4688-b7f5-ea07361b26ae";
  static const String fileRxCharacteristicUuid =
      "beb5483e-36e1-4688-b7f5-ea07361b26af";
  static const String cameraCmdCharacteristicUuid =
      "beb5483e-36e1-4688-b7f5-ea07361b26b1";
  static const String cameraStatusCharacteristicUuid =
      "beb5483e-36e1-4688-b7f5-ea07361b26b2";
}
