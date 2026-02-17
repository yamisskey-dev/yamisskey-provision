# Ansible TDD実践ガイド with Molecule

このドキュメントでは、yamisskey Ansibleプロジェクトでテスト駆動開発（TDD）を実践する方法を説明します。

## 🎯 TDDの基本フロー

### 1. Red - テストを書く（失敗させる）

まず期待される動作を定義するテストを書きます。

```bash
# 新しいロールを作成する場合
ansible-galaxy init ansible_collections/yamisskey/servers/roles/new-role

# Moleculeテストを追加
cd ansible_collections/yamisskey/servers/roles/new-role
./../../../../molecule-templates/setup_molecule.sh
```

### 2. Green - 最小限の実装でテストを通す

テストが通る最小限の実装を行います。

```bash
# 構文チェックで基本エラーを確認
yamisskey-provision test new-role syntax

# 実装後、テストを実行
yamisskey-provision test new-role
```

### 3. Refactor - コードを改善する

テストが通る状態を維持しながらコードを改善します。

## 📋 実践的なTDDワークフロー

### ロール開発のステップ

1. **要件定義とテスト設計**
   ```bash
   # 要件をverify.ymlにテストケースとして記述
   vim ansible_collections/yamisskey/servers/roles/new-role/molecule/default/verify.yml
   ```

2. **テスト実行（Red）**
   ```bash
   yamisskey-provision test new-role syntax    # 構文チェック
   yamisskey-provision test new-role converge  # デプロイテスト
   ```

3. **実装（Green）**
   ```bash
   # tasks/main.ymlに実装を追加
   vim ansible_collections/yamisskey/servers/roles/new-role/tasks/main.yml
   ```

4. **検証とリファクタリング**
   ```bash
   yamisskey-provision test new-role  # 完全テスト
   ```

## 🧪 Moleculeテストの種類

### 構文チェック
```bash
# 単一ロールの構文チェック
yamisskey-provision test garage syntax

# 全ロールの構文チェック
yamisskey-provision test syntax servers
```

### デプロイテスト（Converge）
```bash
# ロールをデプロイしてエラーがないか確認
yamisskey-provision test garage converge
```

### 完全テスト
```bash
# 構文チェック→デプロイ→検証→べき等性チェック
yamisskey-provision test garage
```

### クリーンアップ
```bash
# テスト環境をクリーンアップ
yamisskey-provision test garage cleanup
```

## 📝 テストケースの書き方

### verify.ymlの例

```yaml
---
- name: Verify role deployment
  hosts: all
  gather_facts: false

  tasks:
    - name: Check if service is running
      service:
        name: myservice
        state: started
      register: service_status

    - name: Verify service status
      assert:
        that:
          - service_status.status.ActiveState == "active"
        fail_msg: "Service is not running"
        success_msg: "Service is running correctly"

    - name: Check configuration file
      stat:
        path: /etc/myservice/config.yml
      register: config_file

    - name: Verify configuration exists
      assert:
        that:
          - config_file.stat.exists
        fail_msg: "Configuration file not found"
        success_msg: "Configuration file exists"

    - name: Test API endpoint
      uri:
        url: "http://localhost:8080/health"
        method: GET
        status_code: 200
      register: health_check

    - name: Verify API response
      assert:
        that:
          - health_check.status == 200
        fail_msg: "Health check failed"
        success_msg: "Health check passed"
```

### converge.ymlのカスタマイズ

```yaml
---
- name: Converge
  hosts: all
  become: true
  gather_facts: true

  pre_tasks:
    - name: Update apt cache
      apt:
        update_cache: true
      when: ansible_os_family == "Debian"

    # テスト用のモックデータを準備
    - name: Create test directories
      file:
        path: "{{ item }}"
        state: directory
        mode: '0755'
      loop:
        - /opt/test-app
        - /var/log/test-app
        - /etc/test-app

    # テスト用の設定ファイルを作成
    - name: Create mock configuration
      copy:
        content: |
          server:
            port: 8080
            host: localhost
          database:
            url: sqlite:///tmp/test.db
        dest: /etc/test-app/config.yml
        mode: '0644'

  tasks:
    - name: Apply role under test
      include_role:
        name: yamisskey.servers.new-role
      vars:
        # テスト固有の変数を設定
        app_port: 8080
        app_config_file: /etc/test-app/config.yml
        test_mode: true
```

## 🔄 継続的インテグレーション

### GitHub Actionsとの連携

プロジェクトには既にGitHub Actionsワークフローが設定されています：

- **Pull Request**: 変更されたロールのみテスト実行
- **Main Branch**: 全ロールの構文チェック実行
- **並列実行**: 複数ロールを同時テスト

### ローカル開発でのプリチェック

```bash
# 開発中のロールをプリチェック
yamisskey-provision test your-role syntax

# デプロイテストで基本動作確認
yamisskey-provision test your-role converge

# 完全テスト（時間がかかる）
yamisskey-provision test your-role
```

## 🛠️ デバッグとトラブルシューティング

### テスト失敗時の調査

```bash
# 詳細ログでテスト実行
ANSIBLE_STDOUT_CALLBACK=debug yamisskey-provision test your-role

# コンテナの状態確認
docker ps -a
docker logs <container_id>

# Moleculeコンテナに接続してデバッグ
molecule login
```

### よくある問題と解決策

1. **Docker権限エラー**
   ```bash
   sudo usermod -aG docker $USER
   # ログアウト・ログインが必要
   ```

2. **コレクション参照エラー**
   ```bash
   # ANSIBLE_COLLECTIONS_PATHの設定確認
   export ANSIBLE_COLLECTIONS_PATH=$PWD:$HOME/.ansible/collections
   ```

3. **メモリ不足**
   ```bash
   # Docker設定でメモリ制限を増加
   # または軽量なテストのみ実行
   yamisskey-provision test your-role syntax
   ```

## 📈 ベストプラクティス

### 1. テストファースト開発

- 実装前にverify.ymlでテストケースを定義
- 期待される動作を明確にする
- 失敗するテストから開始する

### 2. 段階的実装

- 構文チェック → デプロイテスト → 検証テスト
- 各段階でテストが通ることを確認
- 一度に多くの機能を実装しない

### 3. テストの独立性

- 各テストは他のテストに依存しない
- クリーンな環境で実行される
- テスト用のモックデータを使用

### 4. 継続的改善

- テスト実行時間の最適化
- テストカバレッジの向上
- テストケースの追加・改善

## 🚀 実践例：新しいロールの開発

### ステップ1: ロール作成とテスト準備

```bash
# 新しいロール作成
ansible-galaxy init ansible_collections/yamisskey/servers/roles/webapp

# Moleculeテスト追加
cd ansible_collections/yamisskey/servers/roles/webapp
../../../../../molecule-templates/setup_molecule.sh
```

### ステップ2: テスト定義（Red）

```yaml
# molecule/default/verify.yml
- name: Verify webapp is running
  uri:
    url: "http://localhost:3000/health"
    status_code: 200

- name: Check webapp service
  service:
    name: webapp
    state: started
```

### ステップ3: 最小実装（Green）

```yaml
# tasks/main.yml
- name: Install webapp
  package:
    name: webapp
    state: present

- name: Start webapp service
  service:
    name: webapp
    state: started
    enabled: yes
```

### ステップ4: テスト実行と改善（Refactor）

```bash
# テスト実行
yamisskey-provision test webapp

# 結果に基づいて改善
# - エラーハンドリング追加
# - 設定ファイルテンプレート作成
# - ヘルスチェック改善
```

この実践的なTDDアプローチにより、信頼性が高く保守しやすいAnsibleロールを開発できます。
