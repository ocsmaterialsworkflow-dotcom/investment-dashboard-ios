import SwiftUI
import InvestAppCore

/// 설정 탭 — 계좌 / API 키 입력 폼.
struct SettingsView: View {

    @Bindable var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss

    /// 각 키별 입력 필드 표시 여부 (보안 토글).
    @State private var revealedKeys: Set<String> = []

    var body: some View {
        NavigationStack {
            List {
                // 상태 메시지 배너
                if let msg = viewModel.statusMessage {
                    Section {
                        Text(msg)
                            .font(.subheadline)
                            .foregroundStyle(viewModel.isStatusError ? .red : Theme.profit)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .listRowBackground(
                        viewModel.isStatusError
                            ? Color.red.opacity(0.08)
                            : Theme.profit.opacity(0.08)
                    )
                }

                // 증권사별 API 키 섹션
                ForEach(viewModel.brokerCredentials) { credential in
                    Section {
                        // 연결 상태 헤더
                        HStack {
                            Text(credential.brokerName)
                                .font(.headline)
                            Spacer()
                            if credential.isSupported {
                                connectionBadge(isConnected: viewModel.isConnected(credential))
                            } else {
                                Text("미지원")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if !credential.isSupported {
                            if let note = credential.unsupportedNote {
                                Text(note)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            ForEach(Array(zip(credential.keys, credential.keyLabels)), id: \.0) { key, label in
                                apiKeyRow(key: key, label: label)
                            }
                        }
                    }
                }

                // 외부 API 키 (BOK, Finnhub)
                Section("외부 API") {
                    ForEach(viewModel.externalKeys, id: \.key) { item in
                        apiKeyRow(key: item.key, label: item.label)
                    }
                }

                // NH 미지원 안내
                Section {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("NH투자증권 미지원")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text("NH투자증권은 현재 Open API 브릿지가 필요해 지원되지 않습니다. 향후 버전에서 추가될 예정입니다.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("API 키 설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("완료") { dismiss() }
                        .foregroundStyle(Theme.profit)
                }
            }
            .onAppear {
                viewModel.loadAll()
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private func apiKeyRow(key: KeychainKey, label: String) -> some View {
        let isRevealed = revealedKeys.contains(key.rawValue)
        let isStored = viewModel.isStored(key)
        let binding = Binding(
            get: { viewModel.inputValues[key, default: ""] },
            set: { viewModel.inputValues[key] = $0 }
        )

        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if isStored {
                    Text(viewModel.maskedValue(for: key))
                        .font(.caption2)
                        .foregroundStyle(Theme.profit)
                }
            }

            HStack(spacing: 8) {
                Group {
                    if isRevealed {
                        TextField(label, text: binding)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    } else {
                        SecureField(label, text: binding)
                    }
                }
                .font(.subheadline)
                .textFieldStyle(.roundedBorder)

                // 표시 토글
                Button {
                    if isRevealed {
                        revealedKeys.remove(key.rawValue)
                    } else {
                        revealedKeys.insert(key.rawValue)
                    }
                } label: {
                    Image(systemName: isRevealed ? "eye.slash" : "eye")
                        .foregroundStyle(.secondary)
                }

                // 저장
                Button {
                    let value = viewModel.inputValues[key, default: ""]
                    viewModel.save(key: key, value: value)
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Theme.profit)
                }

                // 삭제
                if isStored {
                    Button {
                        viewModel.delete(key: key)
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func connectionBadge(isConnected: Bool) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(isConnected ? Theme.profit : Color(.systemGray4))
                .frame(width: 8, height: 8)
            Text(isConnected ? "연결됨" : "미연결")
                .font(.caption)
                .foregroundStyle(isConnected ? Theme.profit : .secondary)
        }
    }
}
