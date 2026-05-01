import SwiftUI

struct DownloadProgressView: View {
    let stage: DownloadStage
    let status: String
    let preview: PreviewMetadata?
    let url: String
    var onCancel: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 22) {
                artwork
                titleSection
                progressSection
                if let onCancel {
                    HStack {
                        Spacer()
                        Button(role: .destructive, action: onCancel) {
                            Label("キャンセル", systemImage: "xmark.circle.fill")
                        }
                        .controlSize(.regular)
                    }
                }
            }
            .frame(maxWidth: 540)
            .card()

            Spacer()
            Spacer()
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var artwork: some View {
        ZStack {
            ArtworkView(path: preview?.thumbnailPath, size: 200)
                .opacity(preview == nil ? 0.65 : 1)
                .blur(radius: preview == nil ? 4 : 0)

            if preview == nil {
                ProgressView()
                    .controlSize(.large)
            }
        }
        .animation(Theme.primaryAnimation, value: preview)
    }

    @ViewBuilder
    private var titleSection: some View {
        VStack(spacing: 6) {
            if let preview {
                Text(preview.title)
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    Text(preview.uploader)
                    if let dur = formatDuration(preview.duration) {
                        Text("·")
                        Text(dur)
                    }
                }
                .font(.callout)
                .foregroundStyle(.secondary)
            } else {
                Text("情報を取得中…")
                    .font(.title3.weight(.semibold))
                Text(url)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
    }

    @ViewBuilder
    private var progressSection: some View {
        VStack(spacing: 10) {
            switch stage {
            case .downloading(let p):
                ProgressView(value: p)
                    .progressViewStyle(.linear)
                HStack {
                    Text(stageLabel)
                    Spacer()
                    Text("\(Int(p * 100))%").monospacedDigit()
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            default:
                ProgressView().progressViewStyle(.linear)
                Text(stageLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var stageLabel: String {
        switch stage {
        case .idle, .starting: return "開始中…"
        case .fetchingInfo: return "情報を取得中…"
        case .downloading: return "ダウンロード中"
        case .extractingAudio: return "音声を抽出中…"
        case .embeddingMetadata: return "メタデータを処理中…"
        }
    }
}
