import Foundation

final class LLMClient {
    private let apiKey: String?
    private let model = "openai/gpt-oss-120b"
    private let endpoint = URL(string: "https://api.groq.com/openai/v1/chat/completions")!
    private let cacheQueue = DispatchQueue(label: "macsense.llm.cache")
    private var cache: [String: String] = [:]

    init() {
        let env = ProcessInfo.processInfo.environment["GROQ_API_KEY"]
        self.apiKey = (env?.isEmpty == false) ? env : nil
        if apiKey == nil {
            print("⚠️  GROQ_API_KEY 환경 변수 없음 — LLM 비활성화")
        } else {
            print("✅ LLM 활성 (Groq · \(model))")
        }
    }

    var isAvailable: Bool { apiKey != nil }

    func suggest(for pattern: DetectedPattern,
                 completion: @escaping (String?) -> Void) {
        let key = pattern.app + "::" + pattern.path

        let cached: String? = cacheQueue.sync { cache[key] }
        if let cached = cached {
            DispatchQueue.main.async { completion(cached) }
            return
        }

        guard let apiKey = apiKey else {
            DispatchQueue.main.async { completion(nil) }
            return
        }

        let prompt = buildPrompt(for: pattern)

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "max_tokens": 200,
            "temperature": 0.7
        ]

        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else {
            DispatchQueue.main.async { completion(nil) }
            return
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "authorization")
        request.httpBody = bodyData
        request.timeoutInterval = 10

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            let text = self?.parse(data: data, response: response, error: error)
            if let text = text {
                self?.cacheQueue.sync { self?.cache[key] = text }
            }
            DispatchQueue.main.async {
                completion(text)
            }
        }.resume()
    }

    private func buildPrompt(for pattern: DetectedPattern) -> String {
        """
        사용자가 macOS에서 다음 UI 클릭을 \(pattern.count)번 반복했습니다.

        앱: \(pattern.app)
        UI 요소: \(pattern.leafRole) "\(pattern.leafLabel)"
        UI 경로: \(pattern.path)

        이 행동은 공식 단축키 DB에서 찾지 못했습니다.
        없는 단축키를 지어내지 말고, macOS Shortcuts 또는 Automator로 만들 수 있는 사용자 자동화 레시피를 추천해주세요.

        출력 규칙:
        - 한국어로 최대 3줄
        - 1줄: "추천 키: ..." 또는 "방법: ..."
        - 2줄: "단계: 앱 열기 → 메뉴/동작 실행" 형식
        - 3줄: 짧은 주의사항이 있을 때만 작성
        - 공식 단축키라고 단정하지 말 것
        - 사족 없이 레시피만 출력
        """
    }

    private func parse(data: Data?, response: URLResponse?, error: Error?) -> String? {
        if let error = error {
            print("❌ LLM 요청 실패: \(error.localizedDescription)")
            return nil
        }
        guard let data = data else { return nil }

        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            let body = String(data: data, encoding: .utf8) ?? ""
            print("❌ LLM HTTP \(http.statusCode): \(body)")
            return nil
        }

        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = json["choices"] as? [[String: Any]],
            let first = choices.first,
            let message = first["message"] as? [String: Any],
            let text = message["content"] as? String
        else {
            return nil
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
