(() => {
  'use strict';

  const app = document.getElementById('app');
  const toast = document.getElementById('toast');
  const fileInput = document.getElementById('photoFileInput');

  const IMG = {
    blackboardWorker: 'assets/photos/blackboard_worker.jpg',
    blackboardClose: 'assets/photos/blackboard_close.jpg',
    blackboardTruck: 'assets/photos/blackboard_truck.jpg',
    blackboardBoard: 'assets/photos/blackboard_board.jpg',
    normalSite: 'assets/photos/normal_site.jpg',
    ocrLarge: 'assets/photos/ocr_large.jpg'
  };

  let lastBaseScreen = 'shipment-detail';
  let filePickMode = 'normal';
  let idSeq = 100;
  let toastTimer = null;
  let state = createInitialState();

  function createInitialState() {
    const schedules = [
      {
        id: 'SCH-001', no: '001', siteName: 'リバティ現場', detailSiteName: '○○マンション新築工事',
        company: '株式会社リバティ', type: '工程', mix: '普通-30-18-20-N・規格品', mixShort: '18-18-20N',
        quantity: '40.00', vehicles: '10', date: '2026/06/10', address: '東京都○○区○○ 1-2-3', shipmentIds: ['SHIP-001', 'SHIP-002']
      },
      {
        id: 'SCH-002', no: '002', siteName: 'リバティ現場', detailSiteName: '△△橋梁補修工事',
        company: '株式会社リバティ', type: '製品', mix: '普通-30-18-20-BB・規格品', mixShort: '21-18-20BB',
        quantity: '20.00', vehicles: '5', date: '2026/06/10', address: '東京都□□区□□ 3-4-5', shipmentIds: ['SHIP-003']
      },
      {
        id: 'SCH-003', no: '003', siteName: 'リバティ現場', detailSiteName: '□□物流センター増築工事',
        company: '株式会社リバティ', type: '代行', mix: '普通-30-18-20-N・規格品', mixShort: '18-18-20N',
        quantity: '80.00', vehicles: '20', date: '2026/06/10', address: '東京都△△区△△ 5-6-7', shipmentIds: ['SHIP-004']
      }
    ];

    const shipments = {
      'SHIP-001': {
        id: 'SHIP-001', scheduleId: 'SCH-001', no: '001', time: '10:30', vehicle: '12', quantity: '4.0m³', quantityValue: '4.00', mix: '18-18-20N',
        cumulativeQty: '-', cumulativeCars: '-', sourceLocalId: 'SYUKKA-LOCAL-001', photoIds: ['PHOTO-001', 'PHOTO-002'], syncStatus: '送信済'
      },
      'SHIP-002': {
        id: 'SHIP-002', scheduleId: 'SCH-001', no: '002', time: '09:30', vehicle: '0101', quantity: '4.0m³', quantityValue: '4.00', mix: '18-18-20N',
        cumulativeQty: '-', cumulativeCars: '-', sourceLocalId: 'SYUKKA-LOCAL-002', photoIds: [], syncStatus: '未送信'
      },
      'SHIP-003': {
        id: 'SHIP-003', scheduleId: 'SCH-002', no: '001', time: '11:00', vehicle: '18', quantity: '4.0m³', quantityValue: '4.00', mix: '21-18-20BB',
        cumulativeQty: '-', cumulativeCars: '-', sourceLocalId: 'SYUKKA-LOCAL-003', photoIds: ['PHOTO-003'], syncStatus: '同期済'
      },
      'SHIP-004': {
        id: 'SHIP-004', scheduleId: 'SCH-003', no: '001', time: '13:00', vehicle: '22', quantity: '4.0m³', quantityValue: '4.00', mix: '18-18-20N',
        cumulativeQty: '-', cumulativeCars: '-', sourceLocalId: 'SYUKKA-LOCAL-004', photoIds: ['PHOTO-004'], syncStatus: '送信済'
      }
    };

    const photos = {
      'PHOTO-001': {
        id: 'PHOTO-001', shipmentId: 'SHIP-001', image: IMG.blackboardWorker, takenAt: '2026/06/10 10:31', sourceType: 'camera', isPrimary: true,
        kind: 'ocr-board', ocrStatus: 'OCR済', confidence: 92, syncStatus: '送信済', blobPath: 'orgs/ORG-001/plants/KOZYO-001/photos/PHOTO-001/original.jpg'
      },
      'PHOTO-002': {
        id: 'PHOTO-002', shipmentId: 'SHIP-001', image: IMG.blackboardClose, takenAt: '2026/06/10 10:32', sourceType: 'camera', isPrimary: false,
        kind: 'normal', ocrStatus: 'OCR対象外', confidence: null, syncStatus: '送信済', blobPath: 'orgs/ORG-001/plants/KOZYO-001/photos/PHOTO-002/original.jpg'
      },
      'PHOTO-003': {
        id: 'PHOTO-003', shipmentId: 'SHIP-003', image: IMG.blackboardBoard, takenAt: '2026/06/10 11:01', sourceType: 'camera', isPrimary: true,
        kind: 'ocr-board', ocrStatus: 'OCR予約済', confidence: null, syncStatus: '同期待ち', blobPath: 'orgs/ORG-001/plants/KOZYO-001/photos/PHOTO-003/original.jpg'
      },
      'PHOTO-004': {
        id: 'PHOTO-004', shipmentId: 'SHIP-004', image: IMG.normalSite, takenAt: '2026/06/10 13:02', sourceType: 'camera', isPrimary: true,
        kind: 'normal', ocrStatus: 'OCR対象外', confidence: null, syncStatus: '送信済', blobPath: 'orgs/ORG-001/plants/KOZYO-001/photos/PHOTO-004/original.jpg'
      }
    };

    return {
      screen: 'login',
      selectedScheduleId: 'SCH-001',
      selectedShipmentId: 'SHIP-001',
      filter: 'all',
      search: '',
      schedules,
      shipments,
      photos,
      pendingPhoto: null,
      selectedPhotoId: 'PHOTO-001',
      lastSave: { photoCount: 2, ocrCount: 1, ocrStatus: 'OCR済', syncStatus: '同期済' }
    };
  }

  function h(value) {
    return String(value ?? '')
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#039;');
  }

  function a(value) { return h(value).replaceAll('`', '&#096;'); }

  function icon(name, fill = false) {
    const cls = fill ? 'svg-icon svg-fill' : 'svg-icon';
    const p = {
      back: '<path d="M19 12H5"/><path d="M12 5l-7 7 7 7"/>',
      menu: '<path d="M4 7h16"/><path d="M4 12h16"/><path d="M4 17h16"/>',
      refresh: '<path d="M20 6v5h-5"/><path d="M4 18v-5h5"/><path d="M18 9a6 6 0 0 0-10-3.5L4 9"/><path d="M6 15a6 6 0 0 0 10 3.5L20 15"/>',
      user: '<path d="M20 21a8 8 0 0 0-16 0"/><circle cx="12" cy="7" r="4"/>',
      lock: '<rect x="5" y="11" width="14" height="10" rx="2"/><path d="M8 11V7a4 4 0 0 1 8 0v4"/><path d="M12 15v3"/>',
      eye: '<path d="M2 12s4-7 10-7 10 7 10 7-4 7-10 7S2 12 2 12Z"/><circle cx="12" cy="12" r="3"/>',
      shield: '<path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10Z"/><path d="M9 12l2 2 4-5"/>',
      calendar: '<rect x="3" y="5" width="18" height="16" rx="2"/><path d="M16 3v4"/><path d="M8 3v4"/><path d="M3 10h18"/>',
      search: '<circle cx="11" cy="11" r="7"/><path d="M20 20l-3.5-3.5"/>',
      flask: '<path d="M10 2h4"/><path d="M11 2v6l-6 10a3 3 0 0 0 2.5 4h9a3 3 0 0 0 2.5-4l-6-10V2"/><path d="M7 16h10"/>',
      truck: '<path d="M3 7h11v9H3z"/><path d="M14 10h4l3 3v3h-7"/><circle cx="7" cy="18" r="2"/><circle cx="18" cy="18" r="2"/>',
      building: '<path d="M4 21V3h10v18"/><path d="M14 8h6v13"/><path d="M7 7h3M7 11h3M7 15h3M17 12h1M17 16h1"/>',
      tag: '<path d="M20 10L12 2H4v8l8 8 8-8Z"/><circle cx="8" cy="6" r="1"/>',
      list: '<path d="M8 6h13M8 12h13M8 18h13"/><path d="M3 6h.01M3 12h.01M3 18h.01"/>',
      person: '<path d="M20 21a8 8 0 0 0-16 0"/><circle cx="12" cy="7" r="4"/>',
      scale: '<path d="M12 3v18"/><path d="M5 6h14"/><path d="M6 6l-3 7h6L6 6Z"/><path d="M18 6l-3 7h6l-3-7Z"/>',
      map: '<path d="M12 21s7-6 7-12a7 7 0 1 0-14 0c0 6 7 12 7 12Z"/><circle cx="12" cy="9" r="2.5"/>',
      nav: '<path d="M22 2L11 13"/><path d="M22 2l-7 20-4-9-9-4 20-7Z"/>',
      camera: '<path d="M4 8h4l2-3h4l2 3h4v12H4z"/><circle cx="12" cy="14" r="4"/>',
      image: '<rect x="3" y="5" width="18" height="14" rx="2"/><path d="M8 13l3-3 7 7"/><path d="M5 17l5-5"/><circle cx="16" cy="9" r="1.5"/>',
      ocr: '<path d="M4 8V4h4"/><path d="M16 4h4v4"/><path d="M20 16v4h-4"/><path d="M8 20H4v-4"/><rect x="7" y="9" width="10" height="6" rx="1"/><path d="M9 12h6"/>',
      info: '<circle cx="12" cy="12" r="10"/><path d="M12 10v7"/><path d="M12 7h.01"/>',
      check: '<path d="M20 6L9 17l-5-5"/>',
      save: '<path d="M19 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11l5 5v11a2 2 0 0 1-2 2Z"/><path d="M17 21v-8H7v8"/><path d="M7 3v5h8"/>',
      clock: '<circle cx="12" cy="12" r="10"/><path d="M12 6v6l4 2"/>',
      trash: '<path d="M3 6h18"/><path d="M8 6V4h8v2"/><path d="M19 6l-1 15H6L5 6"/><path d="M10 11v6M14 11v6"/>',
      star: '<path d="M12 2l2.8 6 6.2.8-4.6 4.4 1.2 6.1L12 16.1 6.4 19.3l1.2-6.1L3 8.8 9.2 8 12 2Z"/>',
      sun: '<circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.93 4.93l1.41 1.41M17.66 17.66l1.41 1.41M2 12h2M20 12h2M4.93 19.07l1.41-1.41M17.66 6.34l1.41-1.41"/>',
      doc: '<path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8Z"/><path d="M14 2v6h6"/><path d="M8 13h8M8 17h6"/>',
      atext: '<path d="M4 20l8-16 8 16"/><path d="M7 14h10"/>',
      tilt: '<path d="M7 3l10 4-4 10-10-4 4-10Z"/><path d="M17 19h4"/><path d="M4 21l3-3"/>',
      chevronRight: '<path d="M9 18l6-6-6-6"/>',
      plus: '<circle cx="12" cy="12" r="10"/><path d="M12 8v8M8 12h8"/>'
    }[name] || '<circle cx="12" cy="12" r="8"/>';
    return `<span class="${cls}" aria-hidden="true"><svg viewBox="0 0 24 24">${p}</svg></span>`;
  }

  function statusBar() {
    return `<div class="status-bar">
      <div>9:41</div>
      <div class="dynamic-island"></div>
      <div class="status-icons"><span class="signal"><span></span><span></span><span></span><span></span></span><span class="wifi"></span><span class="battery"></span></div>
    </div>`;
  }

  function phone(title, body, options = {}) {
    const left = options.left || '';
    const right = options.right || '';
    const line = options.line ? ' with-line' : '';
    const extra = options.extraClass || '';
    return `<main class="demo-stage">
      <section class="phone-frame">
        <span class="phone-side-button"></span>
        <div class="phone-screen ${extra}">
          ${statusBar()}
          ${options.noHeader ? '' : `<header class="app-header${line}">
            <div class="header-left">${left}</div>
            <div class="app-title">${h(title)}</div>
            <div class="header-right">${right}</div>
          </header>`}
          ${body}
        </div>
      </section>
    </main>`;
  }

  function headerBack(to) {
    return `<button class="icon-button" data-action="go" data-screen="${a(to)}" aria-label="戻る">${icon('back')}</button>`;
  }

  function headerMenu() {
    return `<button class="icon-button" data-action="toast" data-message="メニューはデモです" aria-label="メニュー">${icon('menu')}</button>`;
  }

  function headerRefresh() {
    return `<button class="icon-button" data-action="reset" aria-label="更新">${icon('refresh')}</button><span class="refresh-label">更新</span>`;
  }

  function getSchedule(id = state.selectedScheduleId) { return state.schedules.find(s => s.id === id) || state.schedules[0]; }
  function getShipment(id = state.selectedShipmentId) { return state.shipments[id] || state.shipments['SHIP-001']; }
  function photosForShipment(shipmentId = state.selectedShipmentId) {
    const shipment = getShipment(shipmentId);
    return shipment.photoIds.map(id => state.photos[id]).filter(Boolean);
  }
  function primaryPhoto(shipmentId = state.selectedShipmentId) {
    const photos = photosForShipment(shipmentId);
    return photos.find(p => p.isPrimary) || photos[0] || null;
  }
  function ocrBoardPhoto(shipmentId = state.selectedShipmentId) {
    // 仕様上、1つの出荷に対して「有効なOCR黒板」は1件だけ扱う。
    // 新しいOCR黒板を保存した場合は差し替え扱いにし、古い写真は通常写真として残す。
    return photosForShipment(shipmentId).find(p => p.kind === 'ocr-board') || null;
  }
  function shipmentOcrSummary(shipmentId) {
    const board = ocrBoardPhoto(shipmentId);
    if (!board) return { board: '未撮影', status: '未撮影', confidence: '-', className: 'gray', label: 'OCR未撮影' };
    if (board.ocrStatus === 'OCR済') {
      return { board: '撮影済', status: 'OCR済', confidence: `${board.confidence}%`, className: 'ok', label: `OCR済 ${board.confidence}%` };
    }
    if (board.ocrStatus === 'OCR失敗') {
      return { board: '撮影済', status: 'OCR失敗', confidence: '-', className: 'warn', label: 'OCR失敗' };
    }
    return { board: '撮影済', status: 'OCR予約済', confidence: '-', className: 'warn', label: 'OCR予約済' };
  }
  function scheduleOcrSummary(schedule) {
    const summaries = schedule.shipmentIds.map(id => shipmentOcrSummary(id));
    const done = summaries.find(s => s.status === 'OCR済');
    if (done) return done;
    const reserved = summaries.find(s => s.status === 'OCR予約済');
    if (reserved) return reserved;
    return { status: '未撮影', className: 'gray', label: 'OCR未撮影', confidence: '-' };
  }
  function badge(label, type = 'ok') {
    const cls = type === 'warn' ? 'warn-pill' : type === 'gray' ? 'gray-pill' : 'status-pill';
    return `<span class="${cls}">${h(label)}</span>`;
  }
  function ocrBadgeForSummary(summary) {
    return badge(summary.label, summary.className === 'warn' ? 'warn' : summary.className === 'gray' ? 'gray' : 'ok');
  }
  function photoOcrBadge(photo) {
    if (photo.kind === 'normal') return badge('OCR対象外', 'gray');
    if (photo.ocrStatus === 'OCR済') return badge(`OCR済・信頼度${photo.confidence}%`, 'ok');
    return badge('OCR予約済', 'warn');
  }
  function sourceLabel(photo) { return photo.sourceType === 'library' ? 'ライブラリ' : 'カメラ'; }

  function renderLogin() {
    const body = `<div class="screen-body login-body">
      <div class="login-logo">
        <svg class="infinity-logo" viewBox="0 0 200 84" aria-hidden="true">
          <defs><linearGradient id="logoG" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#1e60ac"/><stop offset="1" stop-color="#2447b6"/></linearGradient></defs>
          <path d="M24 42 C50 4 82 5 100 42 C118 79 150 80 176 42" fill="none" stroke="url(#logoG)" stroke-width="15" stroke-linecap="round"/>
          <path d="M176 42 C150 4 118 5 100 42 C82 79 50 80 24 42" fill="none" stroke="url(#logoG)" stroke-width="15" stroke-linecap="round" opacity=".95"/>
        </svg>
        <h1>現場試験アプリ</h1>
        <p class="login-sub">Liberty Accountでログイン</p>
        <span class="status-pill">OCR黒板取込対応</span>
      </div>
      <div class="input-block">
        <label class="input-label">ユーザーID</label>
        <div class="input-box">${icon('user')}<input value="user@example.com" aria-label="ユーザーID"><span></span></div>
      </div>
      <div class="input-block">
        <label class="input-label">パスワード</label>
        <div class="input-box">${icon('lock')}<input value="・・・・・・・" aria-label="パスワード"><span>${icon('eye')}</span></div>
      </div>
      <div style="margin:0 10px"><button class="primary-button" data-action="login">ログイン</button></div>
      <div class="login-note"><span style="color:var(--teal)">${icon('shield')}</span><span>Liberty AccountのIDとパスワードを<br>入力してください</span></div>
      <div class="divider-or">または</div>
      <button class="forgot-link" data-action="toast" data-message="パスワード再設定はデモです">パスワードをお忘れですか？ <span>›</span></button>
    </div>`;
    return phone('', body, { noHeader: true, extraClass: 'login-screen' });
  }

  function renderScheduleList() {
    const cards = filteredSchedules().map(schedule => scheduleCard(schedule)).join('') || `<div class="empty-state">条件に一致する出荷予定がありません。</div>`;
    const body = `<div class="screen-body">
      <div class="control-card">${icon('calendar')}<span>日付</span><span class="value">2026/06/10</span><span style="margin-left:auto">⌄</span></div>
      <div class="search-card">${icon('search')}<input value="${a(state.search)}" data-action="search" placeholder="現場名・予定Noで検索"></div>
      <div class="tabs">
        ${tabButton('all', 'すべて')}
        ${tabButton('photo-missing', '写真未登録')}
        ${tabButton('ocr-incomplete', 'OCR未完了')}
      </div>
      ${cards}
    </div>`;
    return phone('予定一覧', body, { left: headerMenu(), right: headerRefresh() });
  }

  function filteredSchedules() {
    const q = state.search.trim().toLowerCase();
    return state.schedules.filter(schedule => {
      if (q && !`${schedule.no} ${schedule.siteName} ${schedule.detailSiteName} ${schedule.mix}`.toLowerCase().includes(q)) return false;
      if (state.filter === 'photo-missing') {
        return schedule.shipmentIds.some(id => photosForShipment(id).length === 0);
      }
      if (state.filter === 'ocr-incomplete') {
        return !schedule.shipmentIds.some(id => shipmentOcrSummary(id).status === 'OCR済');
      }
      return true;
    });
  }

  function tabButton(value, label) {
    return `<button class="tab-button ${state.filter === value ? 'active' : ''}" data-action="filter" data-filter="${a(value)}">${h(label)}</button>`;
  }

  function scheduleCard(schedule) {
    const summary = scheduleOcrSummary(schedule);
    return `<article class="schedule-card">
      <div class="card-title-row">
        <span class="no-pill">No: ${h(schedule.no)}</span>
        <strong class="schedule-main-title">${h(schedule.siteName)}</strong>
        <span class="status-pill">${h(schedule.type)}</span>
        ${ocrBadgeForSummary(summary)}
      </div>
      <p class="schedule-sub">${h(schedule.company)}</p>
      <p class="mix-line">${h(schedule.mix)}</p>
      <div class="card-line"></div>
      <div class="metrics">
        <div class="metric"><span class="metric-icon">${icon('flask')}</span><span><small>数量</small><strong>${h(schedule.quantity)}</strong></span></div>
        <div class="vline"></div>
        <div class="metric"><span class="metric-icon">${icon('truck')}</span><span><small>台数</small><strong>${h(schedule.vehicles)}</strong></span></div>
      </div>
      <button class="open-button" data-action="open-schedule" data-id="${a(schedule.id)}">開く <span class="chev">›</span></button>
    </article>`;
  }

  function renderScheduleDetail(showCompactForSheet = false) {
    const schedule = getSchedule();
    const body = `<div class="screen-body ${showCompactForSheet ? 'sheet-base-body' : ''}">
      ${scheduleDetailTop(schedule, showCompactForSheet)}
      <div class="section-label">出荷実績</div>
      ${schedule.shipmentIds.map(id => shipmentRow(state.shipments[id])).join('')}
    </div>`;
    return phone('出荷予定詳細', body, { left: headerBack('schedule-list') });
  }

  function scheduleDetailTop(schedule, compact = false) {
    return `<section class="form-card detail-card">
      <table class="info-table">
        <tr><th><span class="row-icon">${icon('building')}</span>現場</th><td>${h(compact ? schedule.detailSiteName : schedule.siteName)}</td></tr>
        <tr><th><span class="row-icon">${icon('tag')}</span>予定No</th><td>${h(schedule.no)}</td></tr>
        ${compact ? '' : `<tr><th><span class="row-icon">${icon('list')}</span>区分</th><td>${h(schedule.type)}</td></tr><tr><th><span class="row-icon">${icon('person')}</span>会社名</th><td>${h(schedule.company)}</td></tr>`}
        <tr><th><span class="row-icon">${icon('flask')}</span>配合</th><td>${h(schedule.mixShort)}</td></tr>
        ${compact ? '' : `<tr><th><span class="row-icon">${icon('scale')}</span>数量</th><td>${h(schedule.quantity)}</td></tr><tr><th><span class="row-icon">${icon('truck')}</span>台数</th><td>${h(schedule.vehicles)}</td></tr>`}
        <tr><th><span class="row-icon">${icon('calendar')}</span>出荷予定日</th><td>${h(schedule.date)}</td></tr>
      </table>
    </section>
    <section class="address-card form-card">
      <h2>現場住所</h2>
      <p class="address-text">${h(schedule.address)}</p>
      <div class="two-actions"><button class="small-button" data-action="map">${icon('map')}地図を開く</button><button class="small-button" data-action="map">${icon('nav')}ナビ開始</button></div>
    </section>`;
  }

  function shipmentRow(shipment) {
    const summary = shipmentOcrSummary(shipment.id);
    const photos = photosForShipment(shipment.id);
    return `<article class="shipment-card">
      <div class="shipment-top"><span class="no-pill">No: ${h(shipment.no)}</span><strong class="shipment-time">${icon('clock')} ${h(shipment.time.replace(':', ''))}</strong>${ocrBadgeForSummary(summary)}<span class="status-pill">${h(shipment.syncStatus)}</span></div>
      <div class="shipment-mini-grid">
        <div class="mini-cell">${icon('truck')}<small>車番</small><strong>${h(shipment.vehicle)}</strong></div>
        <div class="mini-cell">${icon('flask')}<small>出荷量</small><strong>${h(shipment.quantityValue)}</strong></div>
        <div class="mini-cell">${icon('scale')}<small>累計量</small><strong>${h(shipment.cumulativeQty)}</strong></div>
        <div class="mini-cell">${icon('truck')}<small>写真</small><strong>${photos.length ? `${photos.length}枚` : '未登録'}</strong></div>
        <button class="mini-open" data-action="open-shipment" data-id="${a(shipment.id)}">開く ›</button>
      </div>
    </article>`;
  }

  function renderShipmentDetail() {
    const shipment = getShipment();
    const schedule = getSchedule(shipment.scheduleId);
    const photos = photosForShipment(shipment.id);
    const p1 = photos[0];
    const p2 = photos[1];
    const summary = shipmentOcrSummary(shipment.id);
    const body = `<div class="screen-body">
      <div class="site-heading"><div class="big-icon">${icon('building')}</div><h1>${h(schedule.detailSiteName)}</h1></div>
      <section class="info-card">
        <div class="card-head">${icon('truck')}<h2>出荷情報</h2></div>
        <table class="key-value-table">
          <tr><th>出荷時刻</th><td>${h(shipment.time)}</td></tr>
          <tr><th>車番</th><td>${h(shipment.vehicle)}</td></tr>
          <tr><th>数量</th><td>${h(shipment.quantity)}</td></tr>
          <tr><th>配合</th><td class="accent">${h(shipment.mix)}</td></tr>
        </table>
      </section>
      <section class="photo-section form-card">
        <div class="card-head">${icon('camera')}<h2>写真</h2><span class="status-pill">OCR連携</span></div>
        <table class="photo-status-table">
          <tr><th>状態</th><td>${photos.length ? badge('登録済み') : badge('未登録', 'gray')}</td></tr>
          <tr><th>OCR黒板</th><td>${badge(summary.board, summary.board === '未撮影' ? 'gray' : 'ok')}</td></tr>
          <tr><th>OCR状態</th><td>${badge(summary.status, summary.status === 'OCR予約済' ? 'warn' : summary.status === '未撮影' ? 'gray' : 'ok')}</td></tr>
          <tr><th>信頼度</th><td>${h(summary.confidence)}</td></tr>
          <tr><th>枚数</th><td>${photos.length ? `${photos.length}枚` : '0枚'}</td></tr>
          <tr><th>同期状態</th><td>${badge(shipment.syncStatus === '未送信' ? '未送信' : shipment.syncStatus, shipment.syncStatus === '未送信' ? 'gray' : 'ok')}</td></tr>
        </table>
        ${photos.length ? `<div class="thumb-row">
          <img src="${a((p1 || {}).image)}" alt="代表写真" data-action="photo-detail" data-id="${a((p1 || {}).id)}">
          <img src="${a((p2 || p1 || {}).image)}" alt="写真" data-action="photo-detail" data-id="${a((p2 || p1 || {}).id)}">
        </div>` : `<div class="empty-state">まだ写真が登録されていません。<br>写真追加から OCR黒板写真を撮影できます。</div>`}
      </section>
      <div class="footer-actions"><button class="primary-button" data-action="show-menu">${icon('camera')}写真を追加</button><button class="secondary-button" data-action="photo-list">${icon('image')}写真一覧を見る</button></div>
    </div>`;
    return phone('出荷実績詳細', body, { left: headerBack('schedule-detail'), line: true });
  }

  function renderPhotoMenu() {
    const schedule = getSchedule();
    const shipment = getShipment();
    const base = `<div class="screen-body">
      ${scheduleDetailTop(schedule, true)}
    </div>
    <section class="bottom-sheet">
      <div class="sheet-handle"></div>
      <h2>写真を追加</h2>
      <div class="target-pill"><span class="status-pill">対象: ${h(shipment.time)} / 車番${h(shipment.vehicle)}</span></div>
      <div class="sheet-options">
        <button class="sheet-option" data-action="capture-normal"><span class="option-icon">${icon('camera')}</span><span><strong>カメラで撮影</strong><small>その場で写真を撮影します</small></span><span class="arrow">›</span></button>
        <button class="sheet-option" data-action="capture-ocr"><span class="option-icon">${icon('ocr')}</span><span><strong>OCR取込用黒板を撮影 ${badge('推奨')}</strong><small>黒板を大きく撮影してOCR解析します</small></span><span class="arrow">›</span></button>
        <button class="sheet-option" data-action="choose-library" data-mode="normal"><span class="option-icon">${icon('image')}</span><span><strong>ライブラリから選択</strong><small>既に保存されている写真を選択します</small></span><span class="arrow">›</span></button>
      </div>
      <button class="secondary-button" data-action="go" data-screen="${a(lastBaseScreen)}">キャンセル</button>
    </section>`;
    return phone('出荷予定詳細', base, { left: headerBack(lastBaseScreen), extraClass: 'menu-bg' });
  }

  function renderPhotoConfirm() {
    const shipment = getShipment();
    const pending = state.pendingPhoto || makePendingPhoto('ocr');
    const isOcr = pending.mode === 'ocr';
    const title = isOcr ? 'OCR黒板写真の確認' : '写真の確認';
    const subject = isOcr ? 'OCR取込対象' : '対象出荷';
    const targetCls = isOcr ? 'target-card form-card' : 'target-card form-card highlight';
    const body = `<div class="screen-body">
      <section class="${targetCls}">${icon('truck')}<strong>${h(subject)}</strong><span class="target-value">${h(shipment.time)} / 車番${h(shipment.vehicle)}</span></section>
      <div class="preview-wrap"><img class="preview-photo" src="${a(pending.image)}" alt="確認写真"><span class="overlay-badge">${isOcr ? 'OCR黒板' : '写真'}</span></div>
      <div class="photo-note">${icon('info')}<span>${isOcr ? 'この黒板写真からフレッシュ試験値をOCR取込します。' : 'この写真は出荷実績に紐づけられます。'}</span></div>
      <div class="confirm-actions"><button class="primary-button" data-action="set-pending-primary">${isOcr ? 'OCR黒板に設定' : '代表写真に設定'}</button><button class="secondary-button" data-action="discard-pending">写真を削除</button></div>
      <section class="quality-card form-card">
        <h2>${isOcr ? 'OCR品質チェック' : '品質チェック'}</h2>
        <div class="quality-grid">
          <div class="quality-item">${icon(isOcr ? 'doc' : 'sun')}<small>${isOcr ? '黒板の見やすさ' : '明るさ'}</small><strong>良好</strong></div>
          <div class="quality-item">${icon(isOcr ? 'atext' : 'image')}<small>${isOcr ? '文字の鮮明さ' : '写真の見やすさ'}</small><strong>良好</strong></div>
          <div class="quality-item">${icon('tilt')}<small>${isOcr ? '傾き補正' : '傾き'}</small><strong>軽微</strong></div>
        </div>
      </section>
      <button class="primary-button" data-action="save-pending">${isOcr ? 'OCR取込用に保存する' : '保存する'}</button>
      <div class="bottom-two" style="margin-top:14px"><button class="secondary-button" data-action="retake">撮り直す</button><button class="secondary-button" data-action="show-menu">写真を選び直す</button></div>
    </div>`;
    return phone(title, body, { left: headerBack('photo-menu') });
  }

  function renderPhotoList() {
    const shipment = getShipment();
    const photos = photosForShipment(shipment.id);
    const summary = shipmentOcrSummary(shipment.id);
    const list = photos.map(photo => photoListCard(photo)).join('') || `<div class="empty-state">写真がありません。</div>`;
    const body = `<div class="screen-body">
      <section class="target-card form-card highlight">${icon('truck')}<strong>対象出荷: ${h(shipment.time)} / 車番${h(shipment.vehicle)}</strong><span>${ocrBadgeForSummary(summary)}</span></section>
      ${list}
      <div class="photo-list-footer"><button class="primary-button" data-action="save-list">${icon('save')}保存する</button><button class="secondary-button" data-action="show-menu">${icon('plus')}写真を追加</button></div>
    </div>`;
    return phone('写真の確認', body, { left: headerBack('shipment-detail') });
  }

  function photoListCard(photo) {
    const primary = photo.isPrimary ? `<span class="overlay-badge">代表写真</span>` : '';
    const kindBadge = photo.kind === 'ocr-board' ? `<span class="overlay-badge" style="top:${photo.isPrimary ? 56 : 14}px;${photo.ocrStatus === 'OCR予約済' ? 'background:#fff;color:var(--warn);border:1px solid #e3ad3f;' : ''}">OCR黒板</span>` : `<span class="overlay-badge" style="background:#fff;color:#666;border:1px solid #bbb;">通常写真</span>`;
    return `<article class="photo-card">
      <div class="photo-list-img"><img src="${a(photo.image)}" alt="写真 ${h(photo.id)}" data-action="photo-detail" data-id="${a(photo.id)}">${primary}${kindBadge}</div>
      <div class="photo-card-side">
        <div class="photo-date">${icon('clock')} ${h(photo.takenAt)}</div>
        <div>${photoOcrBadge(photo)}</div>
        <div class="photo-actions-stack"><button class="small-primary-outline" data-action="set-primary" data-id="${a(photo.id)}">代表にする</button><button class="small-danger-outline" data-action="delete-photo" data-id="${a(photo.id)}">${icon('trash')}削除</button></div>
      </div>
    </article>`;
  }

  function renderPhotoDetail() {
    const photo = state.photos[state.selectedPhotoId] || primaryPhoto();
    const shipment = getShipment(photo.shipmentId);
    const body = `<div class="screen-body">
      <section class="target-card form-card highlight">${icon('truck')}<strong>対象出荷</strong><span class="target-value">${h(shipment.time)} / 車番${h(shipment.vehicle)}</span></section>
      <div class="detail-photo-main"><img src="${a(photo.image)}" alt="写真詳細"><span class="overlay-badge">${photo.kind === 'ocr-board' ? 'OCR黒板' : '通常写真'}</span></div>
      <section class="meta-card form-card">
        <div class="meta-grid">
          <div class="meta-row"><span>撮影日時</span><strong>${h(photo.takenAt)}</strong></div>
          <div class="meta-row"><span>登録元</span><strong>${h(sourceLabel(photo))}</strong></div>
          <div class="meta-row"><span>代表写真</span><strong>${photo.isPrimary ? 'はい' : 'いいえ'}</strong></div>
          <div class="meta-row"><span>OCR状態</span><strong>${h(photo.ocrStatus)}${photo.confidence ? ` / ${photo.confidence}%` : ''}</strong></div>
          <div class="meta-row"><span>同期状態</span><strong>${h(photo.syncStatus)}</strong></div>
          <div class="meta-row"><span>Blob Path</span><strong style="font-size:12px;word-break:break-all">${h(photo.blobPath)}</strong></div>
        </div>
      </section>
      <div class="confirm-actions"><button class="primary-button" data-action="set-primary" data-id="${a(photo.id)}">代表写真にする</button><button class="danger-button" data-action="delete-photo" data-id="${a(photo.id)}">${icon('trash')}削除</button></div>
    </div>`;
    return phone('写真詳細', body, { left: headerBack('photo-list') });
  }

  function renderSaveComplete() {
    const shipment = getShipment();
    const last = state.lastSave;
    const body = `<div class="screen-body complete-body">
      <div class="check-hero"><span class="sparkle s1">✦</span><span class="sparkle s2">✦</span><span class="sparkle s3">✦</span><div class="check-circle">${icon('check')}</div></div>
      <h1 class="complete-title">写真を保存しました。</h1>
      <p class="complete-sub">以下の出荷実績に写真を保存しました。</p>
      <div class="badge-row">${badge(last.ocrStatus, last.ocrStatus === 'OCR予約済' ? 'warn' : 'ok')}${badge(last.syncStatus)}</div>
      <section class="result-card">
        <div class="card-head">${icon('building')}<h2 style="color:var(--ink)">対象の出荷実績</h2></div>
        <div class="result-split">
          <div class="result-item"><small>${icon('clock')}出荷時刻</small><strong>${h(shipment.time)}</strong></div>
          <div class="vline"></div>
          <div class="result-item"><small>${icon('truck')}車番</small><strong>${h(shipment.vehicle)}</strong></div>
        </div>
      </section>
      <section class="result-card">
        <div class="card-head">${icon('doc')}<h2 style="color:var(--ink)">保存内容のサマリー</h2></div>
        <table class="summary-table">
          <tr><th>写真</th><td>${h(last.photoCount)}枚</td></tr>
          <tr><th>OCR黒板</th><td>${h(last.ocrCount)}枚</td></tr>
          <tr><th>OCR状態</th><td>${badge(last.ocrStatus, last.ocrStatus === 'OCR予約済' ? 'warn' : 'ok')}</td></tr>
          <tr><th>同期状態</th><td>${badge(last.syncStatus)}</td></tr>
        </table>
      </section>
      <div class="complete-actions"><button class="primary-button" data-action="go" data-screen="shipment-detail">出荷実績詳細へ戻る <span style="margin-left:auto">›</span></button><button class="secondary-button" data-action="show-menu">続けて写真を追加 <span style="margin-left:auto">›</span></button></div>
    </div>`;
    return phone('保存完了', body, { right: headerRefresh() });
  }

  function render() {
    const screen = state.screen;
    const html = screen === 'login' ? renderLogin()
      : screen === 'schedule-list' ? renderScheduleList()
      : screen === 'schedule-detail' ? renderScheduleDetail()
      : screen === 'shipment-detail' ? renderShipmentDetail()
      : screen === 'photo-menu' ? renderPhotoMenu()
      : screen === 'photo-confirm' ? renderPhotoConfirm()
      : screen === 'photo-list' ? renderPhotoList()
      : screen === 'photo-detail' ? renderPhotoDetail()
      : screen === 'save-complete' ? renderSaveComplete()
      : renderScheduleList();
    app.innerHTML = html;
  }

  function go(screen) {
    if (screen === 'schedule-list') state.selectedScheduleId = getSchedule().id;
    if (screen === 'shipment-detail') lastBaseScreen = 'shipment-detail';
    state.screen = screen;
    render();
  }

  function makePendingPhoto(mode, image = null, sourceType = 'camera') {
    return {
      mode,
      image: image || (mode === 'ocr' ? IMG.ocrLarge : IMG.normalSite),
      sourceType,
      isPrimary: mode === 'ocr'
    };
  }

  function addPendingPhoto() {
    const pending = state.pendingPhoto || makePendingPhoto('ocr');
    const shipment = getShipment();
    const id = `PHOTO-${++idSeq}`;
    const now = new Date();
    const taken = `2026/06/10 ${shipment.time.slice(0, 2)}:${String(Math.min(59, Number(shipment.time.slice(3, 5)) + 1)).padStart(2, '0')}`;
    const existingPhotos = photosForShipment(shipment.id);
    if (pending.mode === 'ocr') {
      // 有効なOCR黒板は1出荷につき1件。追加時は既存OCR黒板を通常写真扱いへ戻す。
      existingPhotos.forEach(p => {
        if (p.kind === 'ocr-board') {
          p.kind = 'normal';
          p.ocrStatus = 'OCR対象外';
          p.confidence = null;
        }
      });
    }
    const photo = {
      id,
      shipmentId: shipment.id,
      image: pending.image,
      takenAt: taken,
      sourceType: pending.sourceType,
      isPrimary: existingPhotos.length === 0 || pending.isPrimary,
      kind: pending.mode === 'ocr' ? 'ocr-board' : 'normal',
      ocrStatus: pending.mode === 'ocr' ? 'OCR予約済' : 'OCR対象外',
      confidence: null,
      syncStatus: '同期済',
      blobPath: `orgs/ORG-001/plants/KOZYO-001/photos/${id}/original.jpg`
    };
    if (photo.isPrimary) setPrimaryInternal(shipment.id, id);
    state.photos[id] = photo;
    shipment.photoIds.push(id);
    shipment.syncStatus = '同期済';
    if (pending.mode === 'ocr') {
      // 保存完了時点では写真は同期済み、OCRジョブは予約済みとして扱う。
      photo.ocrStatus = 'OCR予約済';
    }
    const photos = photosForShipment(shipment.id);
    const ocrCount = photos.filter(p => p.kind === 'ocr-board').length;
    state.lastSave = {
      photoCount: photos.length,
      ocrCount,
      ocrStatus: pending.mode === 'ocr' ? 'OCR予約済' : (shipmentOcrSummary(shipment.id).status === '未撮影' ? 'OCR対象外' : shipmentOcrSummary(shipment.id).status),
      syncStatus: '同期済'
    };
    state.pendingPhoto = null;
    state.selectedPhotoId = id;
    state.screen = 'save-complete';
    render();
    showToast(pending.mode === 'ocr' ? 'OCR予約を作成しました' : '写真を保存しました');
  }

  function setPrimaryInternal(shipmentId, photoId) {
    photosForShipment(shipmentId).forEach(p => { p.isPrimary = p.id === photoId; });
  }

  function setPrimary(photoId) {
    const photo = state.photos[photoId];
    if (!photo) return;
    setPrimaryInternal(photo.shipmentId, photoId);
    showToast('代表写真を変更しました');
    render();
  }

  function deletePhoto(photoId) {
    const photo = state.photos[photoId];
    if (!photo) return;
    const shipment = state.shipments[photo.shipmentId];
    shipment.photoIds = shipment.photoIds.filter(id => id !== photoId);
    delete state.photos[photoId];
    const remaining = photosForShipment(shipment.id);
    if (remaining.length && !remaining.some(p => p.isPrimary)) remaining[0].isPrimary = true;
    if (state.selectedPhotoId === photoId) state.selectedPhotoId = remaining[0]?.id || '';
    showToast('写真を削除しました');
    if (state.screen === 'photo-detail') state.screen = 'photo-list';
    render();
  }

  function showToast(message) {
    toast.textContent = message;
    toast.classList.add('show');
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => toast.classList.remove('show'), 1800);
  }

  function resetData() {
    const current = state.screen;
    state = createInitialState();
    state.screen = current === 'login' ? 'login' : 'schedule-list';
    showToast('サンプルデータを更新しました');
    render();
  }

  function bindEvents() {
    document.addEventListener('click', event => {
      const el = event.target.closest('[data-action]');
      if (!el) return;
      const action = el.dataset.action;
      if (action === 'login') {
        state.screen = 'schedule-list';
        render();
        return;
      }
      if (action === 'go') {
        go(el.dataset.screen || 'schedule-list');
        return;
      }
      if (action === 'reset') { resetData(); return; }
      if (action === 'toast') { showToast(el.dataset.message || 'デモ操作です'); return; }
      if (action === 'filter') { state.filter = el.dataset.filter || 'all'; render(); return; }
      if (action === 'open-schedule') {
        state.selectedScheduleId = el.dataset.id;
        const schedule = getSchedule();
        state.selectedShipmentId = schedule.shipmentIds[0];
        state.screen = 'schedule-detail';
        render();
        return;
      }
      if (action === 'open-shipment') {
        state.selectedShipmentId = el.dataset.id;
        const shipment = getShipment();
        state.selectedScheduleId = shipment.scheduleId;
        state.screen = 'shipment-detail';
        lastBaseScreen = 'shipment-detail';
        render();
        return;
      }
      if (action === 'map') { showToast('Google Mapsを開くデモです'); return; }
      if (action === 'show-menu') {
        lastBaseScreen = state.screen === 'photo-confirm' ? 'shipment-detail' : state.screen;
        if (!['shipment-detail', 'schedule-detail', 'photo-list', 'save-complete'].includes(lastBaseScreen)) lastBaseScreen = 'shipment-detail';
        state.screen = 'photo-menu';
        render();
        return;
      }
      if (action === 'capture-normal') {
        state.pendingPhoto = makePendingPhoto('normal', IMG.normalSite, 'camera');
        state.screen = 'photo-confirm';
        render();
        return;
      }
      if (action === 'capture-ocr') {
        state.pendingPhoto = makePendingPhoto('ocr', IMG.ocrLarge, 'camera');
        state.screen = 'photo-confirm';
        render();
        return;
      }
      if (action === 'choose-library') {
        filePickMode = el.dataset.mode || 'normal';
        fileInput.value = '';
        fileInput.click();
        return;
      }
      if (action === 'discard-pending') {
        state.pendingPhoto = null;
        state.screen = 'photo-menu';
        render();
        return;
      }
      if (action === 'set-pending-primary') {
        if (!state.pendingPhoto) state.pendingPhoto = makePendingPhoto('ocr');
        state.pendingPhoto.isPrimary = true;
        showToast(state.pendingPhoto.mode === 'ocr' ? 'OCR黒板に設定しました' : '代表写真に設定しました');
        return;
      }
      if (action === 'retake') {
        state.pendingPhoto = makePendingPhoto(state.pendingPhoto?.mode || 'ocr', state.pendingPhoto?.mode === 'normal' ? IMG.normalSite : IMG.ocrLarge, 'camera');
        showToast('撮り直しサンプルを表示しました');
        render();
        return;
      }
      if (action === 'save-pending') { addPendingPhoto(); return; }
      if (action === 'photo-list') { state.screen = 'photo-list'; render(); return; }
      if (action === 'photo-detail') {
        const id = el.dataset.id;
        if (id) state.selectedPhotoId = id;
        state.screen = 'photo-detail';
        render();
        return;
      }
      if (action === 'set-primary') { setPrimary(el.dataset.id); return; }
      if (action === 'delete-photo') { deletePhoto(el.dataset.id); return; }
      if (action === 'save-list') {
        const shipment = getShipment();
        const photos = photosForShipment(shipment.id);
        const summary = shipmentOcrSummary(shipment.id);
        state.lastSave = {
          photoCount: photos.length,
          ocrCount: photos.filter(p => p.kind === 'ocr-board').length,
          ocrStatus: summary.status === '未撮影' ? 'OCR対象外' : summary.status,
          syncStatus: shipment.syncStatus === '未送信' ? '同期済' : shipment.syncStatus
        };
        shipment.syncStatus = state.lastSave.syncStatus;
        state.screen = 'save-complete';
        render();
        return;
      }
    });

    document.addEventListener('input', event => {
      const el = event.target.closest('[data-action="search"]');
      if (!el) return;
      state.search = el.value;
      render();
      const nextInput = document.querySelector('[data-action="search"]');
      if (nextInput) {
        nextInput.focus();
        nextInput.setSelectionRange(nextInput.value.length, nextInput.value.length);
      }
    });

    fileInput.addEventListener('change', event => {
      const file = event.target.files && event.target.files[0];
      if (!file) return;
      const reader = new FileReader();
      reader.onload = () => {
        state.pendingPhoto = makePendingPhoto(filePickMode, String(reader.result), 'library');
        state.screen = 'photo-confirm';
        render();
      };
      reader.onerror = () => showToast('画像を読み込めませんでした');
      reader.readAsDataURL(file);
    });
  }

  bindEvents();
  render();
})();
