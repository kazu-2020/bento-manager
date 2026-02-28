# Apache ECharts / rails_charts 調査レポート

## 1. Apache ECharts

### 基本情報

| 項目 | 値 |
|------|------|
| npm パッケージ名 | `echarts` |
| 最新安定版 | 6.0.0（2025年8月頃リリース） |
| ライセンス | Apache-2.0 |
| メンテナンス | Apache Software Foundation が管理。活発にメンテナンスされている |
| GitHub | https://github.com/apache/echarts |

### 複数シリーズの折れ線グラフ

対応済み。`series` 配列に複数の `{ type: 'line', data: [...] }` オブジェクトを定義するだけで実現可能。

```javascript
option = {
  xAxis: { data: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'] },
  yAxis: {},
  series: [
    { name: '今週', data: [10, 22, 28, 23, 19], type: 'line' },
    { name: '先週', data: [25, 14, 23, 35, 10], type: 'line' }
  ]
};
```

### バンドルサイズ / Tree-shaking

- **フルバンドル**: 約 800KB〜1MB（minified）。gzipped で約 300KB 前後
- **Tree-shaking 対応**: v5 以降で対応。必要なモジュールだけインポート可能
- 折れ線グラフだけなら約 400KB（minified）程度まで削減可能

**Tree-shaking パターン:**

```javascript
import * as echarts from 'echarts/core';
import { LineChart } from 'echarts/charts';
import {
  TitleComponent,
  TooltipComponent,
  GridComponent,
} from 'echarts/components';
import { CanvasRenderer } from 'echarts/renderers';

echarts.use([
  LineChart,
  TitleComponent,
  TooltipComponent,
  GridComponent,
  CanvasRenderer
]);
```

### Stimulus コントローラとの統合パターン

ECharts 専用の Stimulus コンポーネントライブラリは存在しない（Chart.js には `stimulus-chartjs` がある）。
自作 Stimulus コントローラで統合するパターンが標準的。

```javascript
// app/javascript/controllers/echarts_controller.js
import { Controller } from "@hotwired/stimulus"
import * as echarts from 'echarts/core'
import { LineChart } from 'echarts/charts'
import { GridComponent, TooltipComponent, LegendComponent } from 'echarts/components'
import { CanvasRenderer } from 'echarts/renderers'

echarts.use([LineChart, GridComponent, TooltipComponent, LegendComponent, CanvasRenderer])

export default class extends Controller {
  static values = { option: Object }

  connect() {
    this.chart = echarts.init(this.element)
    this.chart.setOption(this.optionValue)
    window.addEventListener('resize', this.handleResize)
  }

  disconnect() {
    window.removeEventListener('resize', this.handleResize)
    this.chart?.dispose()
  }

  handleResize = () => {
    this.chart?.resize()
  }
}
```

### インストール方法（Vite + npm）

```bash
npm install echarts
```

Vite は ESM ネイティブなので、tree-shaking が自動的に効く。


---

## 2. rails_charts gem

### 基本情報

| 項目 | 値 |
|------|------|
| gem 名 | `rails_charts` |
| 最新版 | 1.0.0（2025年9月13日） |
| 内部 ECharts | v6.0 |
| GitHub Stars | 358 |
| 総ダウンロード | 約 87,000 |
| ライセンス | MIT |
| GitHub | https://github.com/railsjazz/rails_charts |

### バージョン履歴

| バージョン | リリース日 |
|-----------|-----------|
| 1.0.0 | 2025-09-13 |
| 0.0.9 | 2025-08-17 |
| 0.0.8 | 2025-08-17 |
| 0.0.7 | 2025-05-28 |
| 0.0.6 | 2023-12-04 |

2023年12月から2025年5月まで約1年半の更新空白期間がある点に注意。

### 複数シリーズの折れ線グラフ

対応済み。配列形式で `{name:, data:}` のハッシュを渡す。

```erb
<%= line_chart [
  { name: "今週", data: { "月" => 10, "火" => 22, "水" => 28 } },
  { name: "先週", data: { "月" => 25, "火" => 14, "水" => 23 } }
] %>
```

### Rails 8 との互換性

README では Rails 6 / Rails 7 のみ言及。Rails 8 の明示的なサポート記述なし。
ただし 1.0.0 は 2025年9月リリースなので、Rails 8 を意識している可能性はある。
動作保証はされていないため、自己検証が必要。

### ViewComponent との統合

README に ViewComponent に関する言及なし。
ヘルパーメソッド（`line_chart`, `area_chart` 等）をビューテンプレートから呼ぶ設計のため、
ViewComponent の `erb` テンプレート内からは呼べるが、公式にテストされた統合ではない。

### Vite Rails との互換性

README では以下の 3 パターンのみ記載:
1. Asset Pipeline（Sprockets）: `//= require echarts.min.js`
2. Webpack / esbuild: `yarn add echarts` + ES6 import
3. Importmap: `config/importmap.rb` で pin

**Vite への言及なし。** Vite で使う場合、Webpack/esbuild パターンに準じて `npm install echarts` +
import で動く可能性はあるが、gem のインストーラ（`rails rails_charts:install`）が
Vite を認識しない可能性が高い。手動セットアップが必要になる。

### ECharts の読み込み方法

gem 内部に ECharts の JS ファイルをベンダリング（同梱）している。
`app/assets/javascripts/echarts.min.js` として配置する設計。
CDN ではなくローカルファイル方式。


---

## 3. 比較判断材料

### Chart.js vs ECharts

| 観点 | Chart.js | ECharts |
|------|----------|---------|
| バンドルサイズ (gzipped) | 約 70KB | フル: 約 300KB / tree-shaking 後: 約 150KB |
| Tree-shaking | v3 以降対応 | v5 以降対応 |
| Stimulus 統合 | `stimulus-chartjs` 公式あり | 公式なし（自作が必要） |
| チャート種類 | 基本的なチャート中心 | 非常に豊富（30+種類） |
| 大規模データ | 数千ポイントまで | 数万〜数百万ポイントに対応 |
| レスポンシブ | 自動リサイズ対応 | `resize()` を手動呼び出し |
| アニメーション | 基本的 | 高度なアニメーション多数 |
| ドキュメント（日本語） | やや少ない | 中国語/英語中心だが豊富 |
| npm weekly downloads | 約 400 万 | 約 150 万 |

### rails_charts vs 直接 ECharts を Stimulus で制御

| 観点 | rails_charts gem | 直接 ECharts + Stimulus |
|------|-----------------|------------------------|
| 導入の手軽さ | ヘルパー1行でチャート描画 | Stimulus コントローラの自作が必要 |
| Vite 互換性 | 不明（未対応の可能性） | npm install で完全対応 |
| Tree-shaking | 不可（ベンダリングされた全体 JS） | 可能（必要モジュールだけ import） |
| ViewComponent 連携 | 公式サポートなし | 自由に設計可能 |
| バージョン管理 | gem のアップデートに依存 | npm で自由に管理 |
| カスタマイズ性 | options ハッシュで渡す。制約あり | ECharts API を直接利用。制約なし |
| Turbo 対応 | 不明 | Stimulus lifecycle で明示的に制御可能 |
| メンテナンスリスク | 小規模 gem（87K DL）。更新空白期間あり | Apache Foundation プロジェクト。安定 |


---

## 4. このプロジェクトへの推奨

### プロジェクト技術スタック（現状）
- Rails 8.1.2
- Vite（vite_rails gem）
- Stimulus（@hotwired/stimulus）
- ViewComponent
- Tailwind CSS v4 + DaisyUI v5

### 推奨: 直接 ECharts + 自作 Stimulus コントローラ

**理由:**

1. **Vite との親和性**: `npm install echarts` で即座に使える。tree-shaking も Vite が自動処理
2. **ViewComponent との統合**: コンポーネント内で `data-controller="echarts"` を使い、`data-echarts-option-value` で JSON を渡す設計が自然
3. **rails_charts の Vite 非対応リスク**: gem のインストーラが Vite を認識しない。手動セットアップが必要な上、内部のベンダリングされた JS がバンドルサイズを膨らませる
4. **Stimulus ライフサイクルとの統合**: `connect()` / `disconnect()` で ECharts インスタンスの生成・破棄を明示的に制御でき、Turbo ナビゲーションとの相性が良い
5. **メンテナンス安定性**: Apache Foundation プロジェクト vs 小規模 gem

**Chart.js ではなく ECharts を推奨する理由:**
- このプロジェクトの用途（弁当屋の売上推移等）では Chart.js で十分だが、ECharts は tree-shaking 後のサイズ差がそこまで大きくなく、将来的な拡張性（ヒートマップ、複合チャート等）で優れる
- ただし **Chart.js の方がシンプルで `stimulus-chartjs` が既にある** ため、チャートが折れ線グラフ1〜2個だけなら Chart.js の方が合理的

### 最終判断

チャートの用途が「折れ線グラフ2本程度」に限定されるなら **Chart.js + stimulus-chartjs** が最小工数。
将来的にチャート種類が増える見込みがあるなら **ECharts + 自作 Stimulus コントローラ** が拡張性で優る。

いずれにせよ **rails_charts gem は推奨しない**。Vite 環境との互換性が不確実で、tree-shaking が効かず、メンテナンスの継続性にリスクがある。
