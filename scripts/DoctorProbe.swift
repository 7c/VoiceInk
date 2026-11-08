// Read-only capability probe. Linked with the production network guard by doctor.
import Foundation
import Speech
import CoreAudio

@main struct DoctorProbe {
    static func main() async throws {
        var inputDevice = AudioDeviceID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        let audioStatus = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &inputDevice)
        let result: [String: Any] = [
            "installedLocales": await SpeechTranscriber.installedLocales.map { $0.identifier(.bcp47) }.sorted(),
            "hasDefaultInput": audioStatus == noErr && inputDevice != kAudioObjectUnknown,
            "audioStatus": audioStatus
        ]
        print(String(decoding: try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys]), as: UTF8.self))
    }
}
