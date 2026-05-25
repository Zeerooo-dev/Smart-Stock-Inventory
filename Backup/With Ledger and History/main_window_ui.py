# -*- coding: utf-8 -*-
# SmartStock Inventory Systeme – Main Window UI

from PyQt5 import QtCore, QtGui, QtWidgets


# ─────────────────────────────────────────────────────────────
#  Colour palette (Material Design 3 tokens from the HTML)
# ─────────────────────────────────────────────────────────────
COLOR = {
    "background":             "#faf8ff",
    "surface":                "#faf8ff",
    "surface_bright":         "#faf8ff",
    "surface_container_low":  "#f3f3fe",
    "surface_container":      "#ededf9",
    "surface_container_high": "#e7e7f3",
    "surface_container_highest": "#e1e2ed",
    "surface_container_lowest":  "#ffffff",
    "outline_variant":        "#c3c6d7",
    "outline":                "#737686",
    "on_surface":             "#191b23",
    "on_surface_variant":     "#434655",
    "secondary":              "#505f76",
    "secondary_container":    "#d0e1fb",
    "on_secondary_container": "#54647a",
    "primary":                "#004ac6",
    "primary_container":      "#2563eb",
    "on_primary_container":   "#eeefff",
    "on_primary":             "#ffffff",
    "error":                  "#ba1a1a",
    "error_container":        "#ffdad6",
    "on_error_container":     "#93000a",
    "tertiary_container":     "#bc4800",
    "on_tertiary_fixed_variant": "#7d2d00",
}

# ─────────────────────────────────────────────────────────────
#  Shared stylesheet
# ─────────────────────────────────────────────────────────────
BASE_STYLE = f"""
    QMainWindow, QWidget {{
        background-color: {COLOR['background']};
        color: {COLOR['on_surface']};
        font-family: 'Inter', 'Segoe UI', sans-serif;
        font-size: 14px;
    }}

    /* ── Top Nav Bar ─────────────────────────── */
    #topNavBar {{
        background-color: {COLOR['surface']};
        border-bottom: 1px solid {COLOR['outline_variant']};
    }}
    #appTitle {{
        font-size: 18px;
        font-weight: 700;
        color: {COLOR['primary']};
    }}
    #navBtn {{
        background: transparent;
        border: none;
        color: {COLOR['secondary']};
        font-size: 14px;
        padding: 4px 12px;
        border-bottom: 2px solid transparent;
    }}
    #navBtn:hover {{ color: {COLOR['primary']}; }}
    #navBtnActive {{
        background: transparent;
        border: none;
        border-bottom: 2px solid {COLOR['primary']};
        color: {COLOR['primary']};
        font-size: 14px;
        font-weight: 700;
        padding: 4px 12px;
    }}

    /* ── Panels / Cards ──────────────────────── */
    #card {{
        background-color: {COLOR['surface_container_lowest']};
        border: 1px solid {COLOR['outline_variant']};
        border-radius: 8px;
    }}
    #cardHeader {{
        background-color: {COLOR['surface_bright']};
        border-bottom: 1px solid {COLOR['outline_variant']};
        border-top-left-radius: 8px;
        border-top-right-radius: 8px;
    }}
    #sectionTitle {{
        font-size: 16px;
        font-weight: 600;
        color: {COLOR['on_surface']};
    }}
    #sectionSubtitle {{
        font-size: 12px;
        color: {COLOR['on_surface_variant']};
    }}

    /* ── Form inputs ─────────────────────────── */
    QLineEdit, QSpinBox, QDoubleSpinBox, QComboBox {{
        background-color: {COLOR['surface_container_lowest']};
        border: 1px solid {COLOR['outline_variant']};
        border-radius: 6px;
        padding: 6px 10px;
        font-size: 14px;
        color: {COLOR['on_surface']};
    }}
    QLineEdit:focus, QSpinBox:focus, QDoubleSpinBox:focus, QComboBox:focus {{
        border: 2px solid {COLOR['primary_container']};
    }}
    QComboBox QAbstractItemView {{
        background-color: {COLOR['surface_container_lowest']};
        border: 1px solid {COLOR['outline_variant']};
        selection-background-color: {COLOR['surface_container_high']};
        color: {COLOR['on_surface']};
    }}
    QLabel#inputLabel {{
        font-size: 13px;
        font-weight: 600;
        color: {COLOR['on_surface_variant']};
    }}

    /* ── Primary / Add button ────────────────── */
    QPushButton#btnPrimary {{
        background-color: {COLOR['primary_container']};
        color: {COLOR['on_primary_container']};
        border: none;
        border-radius: 6px;
        font-size: 13px;
        font-weight: 600;
        padding: 10px 16px;
    }}
    QPushButton#btnPrimary:hover {{ background-color: #1e56d4; }}
    QPushButton#btnPrimary:pressed {{ background-color: #1748b8; }}

    /* ── Secondary / Clear button ────────────── */
    QPushButton#btnSecondary {{
        background-color: transparent;
        color: {COLOR['secondary']};
        border: 1px solid {COLOR['outline_variant']};
        border-radius: 6px;
        font-size: 13px;
        font-weight: 600;
        padding: 10px 16px;
    }}
    QPushButton#btnSecondary:hover {{ background-color: {COLOR['surface_container_high']}; }}

    /* ── Update / Delete row buttons ─────────── */
    QPushButton#btnUpdate {{
        background-color: {COLOR['secondary_container']};
        color: {COLOR['on_surface']};
        border: none;
        border-radius: 6px;
        font-size: 13px;
        font-weight: 600;
        padding: 8px 16px;
    }}
    QPushButton#btnUpdate:hover {{ background-color: #b7c8e1; }}

    QPushButton#btnDelete {{
        background-color: {COLOR['error_container']};
        color: {COLOR['on_error_container']};
        border: none;
        border-radius: 6px;
        font-size: 13px;
        font-weight: 600;
        padding: 8px 16px;
    }}
    QPushButton#btnDelete:hover {{ background-color: #f0a8a8; }}

    /* ── Table ───────────────────────────────── */
    QTableWidget {{
        background-color: {COLOR['surface_container_lowest']};
        border: none;
        gridline-color: {COLOR['outline_variant']};
        font-size: 14px;
        color: {COLOR['on_surface']};
        selection-background-color: {COLOR['surface_container_high']};
        selection-color: {COLOR['on_surface']};
    }}
    QTableWidget::item {{ padding: 8px 16px; }}
    QTableWidget::item:hover {{ background-color: {COLOR['surface_container_high']}; }}
    QHeaderView::section {{
        background-color: {COLOR['surface_container_low']};
        color: {COLOR['on_surface_variant']};
        font-size: 13px;
        font-weight: 600;
        padding: 10px 16px;
        border: none;
        border-bottom: 1px solid {COLOR['outline_variant']};
    }}

    /* ── List widget (category manager) ─────── */
    QListWidget {{
        background-color: {COLOR['surface_container_lowest']};
        border: 1px solid {COLOR['outline_variant']};
        border-radius: 6px;
        font-size: 14px;
        color: {COLOR['on_surface']};
    }}
    QListWidget::item {{ padding: 6px 12px; }}
    QListWidget::item:selected {{
        background-color: {COLOR['secondary_container']};
        color: {COLOR['on_surface']};
    }}
    QListWidget::item:hover {{ background-color: {COLOR['surface_container_high']}; }}

    /* ── Settings GroupBox ───────────────────── */
    QGroupBox {{
        background-color: {COLOR['surface_container_lowest']};
        border: 1px solid {COLOR['outline_variant']};
        border-radius: 10px;
        margin-top: 16px;
        padding: 12px;
        font-size: 15px;
        font-weight: 600;
        color: {COLOR['on_surface']};
    }}
    QGroupBox::title {{
        subcontrol-origin: margin;
        subcontrol-position: top left;
        left: 14px;
        padding: 0 6px;
        color: {COLOR['on_surface']};
        font-size: 15px;
        font-weight: 600;
    }}

    /* ── Settings specific buttons ───────────── */
    QPushButton#btnSettingsPrimary {{
        background-color: {COLOR['primary']};
        color: {COLOR['on_primary']};
        border: none;
        border-radius: 6px;
        font-size: 13px;
        font-weight: 600;
        padding: 10px 20px;
    }}
    QPushButton#btnSettingsPrimary:hover {{ background-color: #0040b0; }}

    QPushButton#btnDanger {{
        background-color: {COLOR['error']};
        color: #ffffff;
        border: none;
        border-radius: 6px;
        font-size: 13px;
        font-weight: 600;
        padding: 10px 20px;
    }}
    QPushButton#btnDanger:hover {{ background-color: #9e1515; }}

    QPushButton#btnCategoryAdd {{
        background-color: {COLOR['primary_container']};
        color: {COLOR['on_primary_container']};
        border: none;
        border-radius: 6px;
        font-size: 13px;
        font-weight: 600;
        padding: 8px 14px;
    }}
    QPushButton#btnCategoryAdd:hover {{ background-color: #1e56d4; }}

    QPushButton#btnCategoryRemove {{
        background-color: {COLOR['error_container']};
        color: {COLOR['on_error_container']};
        border: none;
        border-radius: 6px;
        font-size: 13px;
        font-weight: 600;
        padding: 8px 14px;
    }}
    QPushButton#btnCategoryRemove:hover {{ background-color: #f0a8a8; }}

    /* ── Export button (Reports) ─────────────── */
    QPushButton#btnExport {{
        background-color: {COLOR['primary_container']};
        color: {COLOR['on_primary_container']};
        border: none;
        border-radius: 6px;
        font-size: 13px;
        font-weight: 600;
        padding: 10px 20px;
    }}
    QPushButton#btnExport:hover {{ background-color: #1e56d4; }}

    /* ── Status bar ──────────────────────────── */
    QStatusBar {{
        background-color: {COLOR['surface_container_low']};
        color: {COLOR['on_surface_variant']};
        border-top: 1px solid {COLOR['outline_variant']};
        font-size: 12px;
        padding: 2px 8px;
    }}

    /* ── Scrollbars ──────────────────────────── */
    QScrollBar:vertical {{
        background: {COLOR['surface_container_low']};
        width: 8px;
        border-radius: 4px;
    }}
    QScrollBar::handle:vertical {{
        background: {COLOR['outline_variant']};
        border-radius: 4px;
        min-height: 20px;
    }}
    QScrollBar::add-line:vertical, QScrollBar::sub-line:vertical {{ height: 0px; }}

    /* ── CheckBox ────────────────────────────── */
    QCheckBox {{
        font-size: 14px;
        font-weight: 600;
        color: {COLOR['on_surface']};
        spacing: 8px;
    }}
    QCheckBox::indicator {{
        width: 18px;
        height: 18px;
        border: 2px solid {COLOR['outline_variant']};
        border-radius: 4px;
        background: {COLOR['surface_container_lowest']};
    }}
    QCheckBox::indicator:checked {{
        background-color: {COLOR['primary']};
        border-color: {COLOR['primary']};
    }}

    /* ── Theme-aware regions (no per-widget light-theme lock-in) ─── */
    QFrame#settingsSidebar {{
        background-color: {COLOR['surface_container_low']};
        border-right: 1px solid {COLOR['outline_variant']};
    }}
    QFrame#inventoryActionBar {{
        background-color: {COLOR['surface_container_low']};
        border-top: 1px solid {COLOR['outline_variant']};
    }}
    QLabel#tableMetaBadge {{
        background-color: {COLOR['surface_container_highest']};
        color: {COLOR['on_surface_variant']};
        font-size: 11px;
        font-weight: 700;
        letter-spacing: 0.06em;
        padding: 2px 8px;
        border-radius: 4px;
    }}
    QLabel#reportPageTitle {{
        font-size: 26px;
        font-weight: 700;
        color: {COLOR['on_surface']};
    }}
    QLabel#reportPageSubtitle {{
        font-size: 14px;
        color: {COLOR['on_surface_variant']};
    }}
    QLabel#settingsPageTitle {{
        font-size: 26px;
        font-weight: 700;
        color: {COLOR['on_surface']};
    }}
    QLabel#settingsPageSubtitle {{
        font-size: 14px;
        color: {COLOR['on_surface_variant']};
    }}
    QLabel#cardHeaderHint {{
        font-size: 12px;
        color: {COLOR['on_surface_variant']};
    }}
    QLabel#kpiCardLabel {{
        font-size: 13px;
        font-weight: 600;
        color: {COLOR['on_surface_variant']};
    }}
    QLabel#kpiCardIcon {{
        font-size: 20px;
    }}
    QLabel#kpiValuePrimary {{
        font-size: 28px;
        font-weight: 700;
        color: {COLOR['primary']};
    }}
    QLabel#kpiValueMoney {{
        font-size: 28px;
        font-weight: 700;
        color: {COLOR['tertiary_container']};
    }}
    QLabel#kpiValueAlert[alert="true"] {{
        font-size: 28px;
        font-weight: 700;
        color: {COLOR['error']};
    }}
    QLabel#kpiValueAlert[alert="false"] {{
        font-size: 28px;
        font-weight: 700;
        color: {COLOR['on_surface']};
    }}
    QLabel#wsBadgeIcon {{
        background-color: {COLOR['secondary_container']};
        color: {COLOR['on_surface']};
        border-radius: 19px;
        font-weight: 700;
        font-size: 15px;
    }}
    QLabel#wsBadgeTitle {{
        font-weight: 700;
        font-size: 14px;
        color: {COLOR['on_surface']};
        background: transparent;
    }}
    QLabel#wsBadgeSubtitle {{
        font-size: 12px;
        color: {COLOR['on_surface_variant']};
        background: transparent;
    }}
    QFrame#wsBadgeRow {{
        background: transparent;
        border: none;
    }}
    QLineEdit#readonlyDbPath {{
        background-color: {COLOR['surface_container_low']};
        color: {COLOR['on_surface']};
        border: 1px solid {COLOR['outline_variant']};
        border-radius: 6px;
        padding: 8px 12px;
        font-family: 'JetBrains Mono', 'Consolas', monospace;
        font-size: 13px;
    }}
    QLabel#mutedNote {{
        font-size: 12px;
        color: {COLOR['outline']};
    }}
    QFrame#dangerZone {{
        background-color: rgba(186, 26, 26, 0.07);
        border: 1px solid rgba(186, 26, 26, 0.25);
        border-radius: 10px;
    }}
    QLabel#dangerTitle {{
        font-size: 13px;
        font-weight: 600;
        color: {COLOR['error']};
        background: transparent;
    }}
    QLabel#dangerDesc {{
        font-size: 12px;
        color: {COLOR['on_surface_variant']};
        background: transparent;
    }}
"""


class Ui_MainWindow:
    def setupUi(self, MainWindow):
        MainWindow.setObjectName("MainWindow")
        MainWindow.setWindowTitle("SmartStock Inventory System")
        MainWindow.resize(1100, 700)
        MainWindow.setMinimumSize(900, 600)
        MainWindow.setStyleSheet(BASE_STYLE)

        self.centralwidget = QtWidgets.QWidget(MainWindow)
        MainWindow.setCentralWidget(self.centralwidget)

        root_layout = QtWidgets.QVBoxLayout(self.centralwidget)
        root_layout.setContentsMargins(0, 0, 0, 0)
        root_layout.setSpacing(0)

        # ── Top Navigation Bar ────────────────────────────────────────
        self.topNavBar = QtWidgets.QFrame()
        self.topNavBar.setObjectName("topNavBar")
        self.topNavBar.setFixedHeight(56)
        nav_layout = QtWidgets.QHBoxLayout(self.topNavBar)
        nav_layout.setContentsMargins(28, 0, 28, 0)
        nav_layout.setSpacing(0)

        self.appTitle = QtWidgets.QLabel("SmartStock Inventory System")
        self.appTitle.setObjectName("appTitle")

        nav_layout.addWidget(self.appTitle)
        nav_layout.addSpacing(32)

        # Nav buttons
        self.btn_nav_dashboard = QtWidgets.QPushButton("Inventory Dashboard")
        self.btn_nav_dashboard.setObjectName("navBtnActive")
        self.btn_nav_dashboard.setCursor(QtGui.QCursor(QtCore.Qt.PointingHandCursor))

        self.btn_nav_reports = QtWidgets.QPushButton("Stock Reports")
        self.btn_nav_reports.setObjectName("navBtn")
        self.btn_nav_reports.setCursor(QtGui.QCursor(QtCore.Qt.PointingHandCursor))

        self.btn_nav_settings = QtWidgets.QPushButton("System Settings")
        self.btn_nav_settings.setObjectName("navBtn")
        self.btn_nav_settings.setCursor(QtGui.QCursor(QtCore.Qt.PointingHandCursor))

        self.btn_nav_audit = QtWidgets.QPushButton("Audit Log")
        self.btn_nav_audit.setObjectName("navBtn")
        self.btn_nav_audit.setCursor(QtGui.QCursor(QtCore.Qt.PointingHandCursor))

        for btn in (self.btn_nav_dashboard, self.btn_nav_reports,
                    self.btn_nav_audit, self.btn_nav_settings):
            nav_layout.addWidget(btn)

        nav_layout.addStretch()

        root_layout.addWidget(self.topNavBar)

        # ── Stacked Pages ─────────────────────────────────────────────
        self.stackedWidget = QtWidgets.QStackedWidget()
        root_layout.addWidget(self.stackedWidget)

        self._build_dashboard_page()
        self._build_reports_page()
        self._build_audit_page()
        self._build_settings_page()

        # Status Bar
        self.statusbar = QtWidgets.QStatusBar(MainWindow)
        MainWindow.setStatusBar(self.statusbar)

        self.retranslateUi(MainWindow)

    # ─────────────────────────────────────────────────────────────────
    #  PAGE 1 – Inventory Dashboard
    # ─────────────────────────────────────────────────────────────────
    def _build_dashboard_page(self):
        self.page_dashboard = QtWidgets.QWidget()
        page_layout = QtWidgets.QHBoxLayout(self.page_dashboard)
        page_layout.setContentsMargins(24, 20, 24, 20)
        page_layout.setSpacing(20)

        # ── LEFT PANEL: Add New Item ──────────────────────────────────
        left_card = QtWidgets.QFrame()
        left_card.setObjectName("card")
        left_card.setFixedWidth(340)
        left_v = QtWidgets.QVBoxLayout(left_card)
        left_v.setContentsMargins(0, 0, 0, 0)
        left_v.setSpacing(0)

        # Card header
        lh = QtWidgets.QFrame()
        lh.setObjectName("cardHeader")
        lh.setFixedHeight(68)
        lh_layout = QtWidgets.QVBoxLayout(lh)
        lh_layout.setContentsMargins(20, 12, 20, 10)
        lh_layout.setSpacing(2)
        t1 = QtWidgets.QLabel("Add New Item")
        t1.setObjectName("sectionTitle")
        t2 = QtWidgets.QLabel("Register a new asset to the central warehouse system.")
        t2.setObjectName("sectionSubtitle")
        t2.setWordWrap(True)
        lh_layout.addWidget(t1)
        lh_layout.addWidget(t2)
        left_v.addWidget(lh)

        # Form body
        form_scroll = QtWidgets.QScrollArea()
        form_scroll.setWidgetResizable(True)
        form_scroll.setFrameShape(QtWidgets.QFrame.NoFrame)
        form_body = QtWidgets.QWidget()
        form_layout = QtWidgets.QVBoxLayout(form_body)
        form_layout.setContentsMargins(20, 16, 20, 16)
        form_layout.setSpacing(14)

        def _field(label_text, widget):
            lbl = QtWidgets.QLabel(label_text)
            lbl.setObjectName("inputLabel")
            form_layout.addWidget(lbl)
            form_layout.addWidget(widget)

        self.input_name_7 = QtWidgets.QLineEdit()
        self.input_name_7.setPlaceholderText("e.g. Industrial Gasket")
        _field("Item Name", self.input_name_7)

        self.combo_category_7 = QtWidgets.QComboBox()
        _field("Category", self.combo_category_7)

        # Qty + Price side by side
        qty_price_row = QtWidgets.QHBoxLayout()
        qty_price_row.setSpacing(12)

        qty_col = QtWidgets.QVBoxLayout()
        qty_lbl = QtWidgets.QLabel("Quantity")
        qty_lbl.setObjectName("inputLabel")
        self.input_qty_7 = QtWidgets.QSpinBox()
        self.input_qty_7.setMinimum(0)
        self.input_qty_7.setMaximum(999999)
        qty_col.addWidget(qty_lbl)
        qty_col.addWidget(self.input_qty_7)

        price_col = QtWidgets.QVBoxLayout()
        price_lbl = QtWidgets.QLabel("Unit Price")
        price_lbl.setObjectName("inputLabel")
        self.input_price_7 = QtWidgets.QDoubleSpinBox()
        self.input_price_7.setMinimum(0.0)
        self.input_price_7.setMaximum(9999999.99)
        self.input_price_7.setDecimals(2)
        self.input_price_7.setSingleStep(1.0)
        self.input_price_7.setPrefix("₱ ")
        price_col.addWidget(price_lbl)
        price_col.addWidget(self.input_price_7)

        qty_price_row.addLayout(qty_col)
        qty_price_row.addLayout(price_col)
        form_layout.addLayout(qty_price_row)

        self.input_reorder_7 = QtWidgets.QSpinBox()
        self.input_reorder_7.setMinimum(0)
        self.input_reorder_7.setMaximum(999999)
        self.input_reorder_7.setValue(5)
        _field("Low Stock Alert Threshold", self.input_reorder_7)

        self.lbl_barcode_preview = QtWidgets.QLabel("Select an item to preview SKU barcode")
        self.lbl_barcode_preview.setObjectName("mutedNote")
        self.lbl_barcode_preview.setAlignment(QtCore.Qt.AlignCenter)
        self.lbl_barcode_preview.setMinimumHeight(120)
        self.lbl_barcode_preview.setScaledContents(True)
        form_layout.addWidget(self.lbl_barcode_preview)

        # Add / Clear
        self.btn_add_7 = QtWidgets.QPushButton("Add Item")
        self.btn_add_7.setObjectName("btnPrimary")
        self.btn_add_7.setCursor(QtGui.QCursor(QtCore.Qt.PointingHandCursor))
        self.btn_clear_7 = QtWidgets.QPushButton("Clear Form")
        self.btn_clear_7.setObjectName("btnSecondary")
        self.btn_clear_7.setCursor(QtGui.QCursor(QtCore.Qt.PointingHandCursor))
        form_layout.addWidget(self.btn_add_7)
        form_layout.addWidget(self.btn_clear_7)
        form_layout.addStretch()

        form_scroll.setWidget(form_body)
        left_v.addWidget(form_scroll)
        page_layout.addWidget(left_card)

        # ── RIGHT PANEL: Inventory Table ─────────────────────────────
        right_card = QtWidgets.QFrame()
        right_card.setObjectName("card")
        right_v = QtWidgets.QVBoxLayout(right_card)
        right_v.setContentsMargins(0, 0, 0, 0)
        right_v.setSpacing(0)

        # Table card header
        rh = QtWidgets.QFrame()
        rh.setObjectName("cardHeader")
        rh.setFixedHeight(62)
        rh_layout = QtWidgets.QHBoxLayout(rh)
        rh_layout.setContentsMargins(20, 10, 16, 10)

        rh_t1 = QtWidgets.QLabel("Warehouse Inventory")
        rh_t1.setObjectName("sectionTitle")
        rh_t2 = QtWidgets.QLabel("TABLE: tableInventory")
        rh_t2.setObjectName("tableMetaBadge")
        rh_layout.addWidget(rh_t1)
        rh_layout.addWidget(rh_t2)
        rh_layout.addStretch()
        right_v.addWidget(rh)

        # Search bar (full-width row below header)
        search_bar = QtWidgets.QFrame()
        search_bar.setObjectName("cardHeader")
        search_layout = QtWidgets.QHBoxLayout(search_bar)
        search_layout.setContentsMargins(20, 10, 20, 10)
        search_layout.setSpacing(12)
        search_lbl = QtWidgets.QLabel("Search Inventory")
        search_lbl.setObjectName("inputLabel")
        search_lbl.setMinimumWidth(110)
        self.search_input = QtWidgets.QLineEdit()
        self.search_input.setPlaceholderText("Filter by name, SKU, or category…")
        self.search_input.setMinimumHeight(36)
        self.search_input.setSizePolicy(
            QtWidgets.QSizePolicy.Expanding, QtWidgets.QSizePolicy.Fixed
        )
        search_layout.addWidget(search_lbl)
        search_layout.addWidget(self.search_input, 1)
        right_v.addWidget(search_bar)

        # Table
        self.tableInventory = QtWidgets.QTableWidget()
        self.tableInventory.setColumnCount(6)
        self.tableInventory.setRowCount(0)
        self.tableInventory.setHorizontalHeaderLabels(
            ["Item ID", "SKU", "Product Name", "Category", "Quantity", "Unit Price (₱)"]
        )
        self.tableInventory.horizontalHeader().setSectionResizeMode(1, QtWidgets.QHeaderView.Stretch)
        self.tableInventory.horizontalHeader().setSectionResizeMode(2, QtWidgets.QHeaderView.Stretch)
        self.tableInventory.setSelectionMode(QtWidgets.QAbstractItemView.SingleSelection)
        self.tableInventory.setSelectionBehavior(QtWidgets.QAbstractItemView.SelectRows)
        self.tableInventory.setEditTriggers(QtWidgets.QAbstractItemView.NoEditTriggers)
        self.tableInventory.verticalHeader().setVisible(False)
        self.tableInventory.setShowGrid(True)
        self.tableInventory.setAlternatingRowColors(False)
        right_v.addWidget(self.tableInventory)

        # Pagination toolbar
        pagination_bar = QtWidgets.QFrame()
        pagination_bar.setObjectName("inventoryActionBar")
        pagination_layout = QtWidgets.QHBoxLayout(pagination_bar)
        pagination_layout.setContentsMargins(16, 6, 16, 6)
        pagination_layout.setSpacing(10)
        self.btn_page_prev = QtWidgets.QPushButton("◀ Previous")
        self.btn_page_prev.setObjectName("btnSecondary")
        self.btn_page_prev.setCursor(QtGui.QCursor(QtCore.Qt.PointingHandCursor))
        self.lbl_page_info = QtWidgets.QLabel("Page 1 of 1")
        self.lbl_page_info.setObjectName("cardHeaderHint")
        self.btn_page_next = QtWidgets.QPushButton("Next ▶")
        self.btn_page_next.setObjectName("btnSecondary")
        self.btn_page_next.setCursor(QtGui.QCursor(QtCore.Qt.PointingHandCursor))
        pagination_layout.addWidget(self.btn_page_prev)
        pagination_layout.addStretch()
        pagination_layout.addWidget(self.lbl_page_info)
        pagination_layout.addStretch()
        pagination_layout.addWidget(self.btn_page_next)
        right_v.addWidget(pagination_bar)

        # Row action buttons (Update / Delete)
        row_btn_bar = QtWidgets.QFrame()
        row_btn_bar.setObjectName("inventoryActionBar")
        row_btn_layout = QtWidgets.QHBoxLayout(row_btn_bar)
        row_btn_layout.setContentsMargins(16, 8, 16, 8)
        row_btn_layout.setSpacing(10)

        self.btn_restock = QtWidgets.QPushButton("+ Restock")
        self.btn_restock.setObjectName("btnSecondary")
        self.btn_restock.setCursor(QtGui.QCursor(QtCore.Qt.PointingHandCursor))

        self.btn_dispense = QtWidgets.QPushButton("- Dispense")
        self.btn_dispense.setObjectName("btnSecondary")
        self.btn_dispense.setCursor(QtGui.QCursor(QtCore.Qt.PointingHandCursor))

        self.btn_view_history = QtWidgets.QPushButton("📋  View History")
        self.btn_view_history.setObjectName("btnSecondary")
        self.btn_view_history.setCursor(QtGui.QCursor(QtCore.Qt.PointingHandCursor))
        self.btn_view_history.setEnabled(False)

        self.btn_update = QtWidgets.QPushButton("✏  Update Selected")
        self.btn_update.setObjectName("btnUpdate")
        self.btn_update.setCursor(QtGui.QCursor(QtCore.Qt.PointingHandCursor))

        self.btn_delete_item = QtWidgets.QPushButton("🗑  Delete Selected")
        self.btn_delete_item.setObjectName("btnDelete")
        self.btn_delete_item.setCursor(QtGui.QCursor(QtCore.Qt.PointingHandCursor))

        row_btn_layout.addStretch()
        row_btn_layout.addWidget(self.btn_restock)
        row_btn_layout.addWidget(self.btn_dispense)
        row_btn_layout.addWidget(self.btn_view_history)
        row_btn_layout.addWidget(self.btn_update)
        row_btn_layout.addWidget(self.btn_delete_item)
        right_v.addWidget(row_btn_bar)

        page_layout.addWidget(right_card)
        self.stackedWidget.addWidget(self.page_dashboard)

    # ─────────────────────────────────────────────────────────────────
    #  PAGE 2 – Stock Reports
    # ─────────────────────────────────────────────────────────────────
    def _build_reports_page(self):
        self.page_reports = QtWidgets.QWidget()
        page_layout = QtWidgets.QVBoxLayout(self.page_reports)
        page_layout.setContentsMargins(28, 20, 28, 20)
        page_layout.setSpacing(20)

        # Page title
        title_row = QtWidgets.QHBoxLayout()
        page_title = QtWidgets.QLabel("Inventory Analytics")
        page_title.setObjectName("reportPageTitle")
        page_sub = QtWidgets.QLabel("Operational overview and stock distribution details.")
        page_sub.setObjectName("reportPageSubtitle")
        title_col = QtWidgets.QVBoxLayout()
        title_col.addWidget(page_title)
        title_col.addWidget(page_sub)
        title_row.addLayout(title_col)
        title_row.addStretch()
        page_layout.addLayout(title_row)

        # ── KPI Cards row ─────────────────────────────────────────────
        kpi_row = QtWidgets.QHBoxLayout()
        kpi_row.setSpacing(16)

        self.lbl_total_items = self._kpi_card(
            "Total Items in Stock", "--", "📦", "kpiValuePrimary"
        )
        self.lbl_low_stock = self._kpi_card(
            "Low Stock Alerts", "--", "⚠", "kpiValueAlert"
        )
        self.lbl_total_value = self._kpi_card(
            "Total Inventory Value", "₱--", "💳", "kpiValueMoney"
        )

        for card, _ in [
            (self._kpi_boxes[0], None),
            (self._kpi_boxes[1], None),
            (self._kpi_boxes[2], None),
        ]:
            kpi_row.addWidget(card)

        page_layout.addLayout(kpi_row)

        # ── Analytics charts (matplotlib canvas host) ───────────────────
        analytics_card = QtWidgets.QFrame()
        analytics_card.setObjectName("card")
        analytics_v = QtWidgets.QVBoxLayout(analytics_card)
        analytics_v.setContentsMargins(0, 0, 0, 0)
        analytics_v.setSpacing(0)
        ah = QtWidgets.QFrame()
        ah.setObjectName("cardHeader")
        ah.setFixedHeight(52)
        ah_layout = QtWidgets.QHBoxLayout(ah)
        ah_layout.setContentsMargins(20, 10, 20, 10)
        ah_title = QtWidgets.QLabel("Multi-Metric Analytics")
        ah_title.setObjectName("sectionTitle")
        ah_sub = QtWidgets.QLabel("Category value distribution & low-stock threats")
        ah_sub.setObjectName("cardHeaderHint")
        ah_layout.addWidget(ah_title)
        ah_layout.addStretch()
        ah_layout.addWidget(ah_sub)
        analytics_v.addWidget(ah)
        self.analytics_scroll = QtWidgets.QScrollArea()
        self.analytics_scroll.setWidgetResizable(True)
        self.analytics_scroll.setFrameShape(QtWidgets.QFrame.NoFrame)
        self.analytics_scroll.setHorizontalScrollBarPolicy(QtCore.Qt.ScrollBarAlwaysOff)
        self.analytics_scroll.setMaximumHeight(275)
        self.analytics_charts_widget = QtWidgets.QWidget()
        self.analytics_charts_layout = QtWidgets.QVBoxLayout(self.analytics_charts_widget)
        self.analytics_charts_layout.setContentsMargins(8, 4, 8, 4)
        self.analytics_charts_layout.setSpacing(0)
        self.analytics_scroll.setWidget(self.analytics_charts_widget)
        analytics_v.addWidget(self.analytics_scroll)
        page_layout.addWidget(analytics_card)

        # ── Category Summary Table ─────────────────────────────────────
        table_card = QtWidgets.QFrame()
        table_card.setObjectName("card")
        table_v = QtWidgets.QVBoxLayout(table_card)
        table_v.setContentsMargins(0, 0, 0, 0)
        table_v.setSpacing(0)

        th = QtWidgets.QFrame()
        th.setObjectName("cardHeader")
        th.setFixedHeight(52)
        th_layout = QtWidgets.QHBoxLayout(th)
        th_layout.setContentsMargins(20, 10, 20, 10)
        th_title = QtWidgets.QLabel("Category Balance Summary")
        th_title.setObjectName("sectionTitle")
        th_sub = QtWidgets.QLabel("Data refreshed on page load")
        th_sub.setObjectName("cardHeaderHint")
        th_layout.addWidget(th_title)
        th_layout.addStretch()
        th_layout.addWidget(th_sub)
        table_v.addWidget(th)

        self.table_reports = QtWidgets.QTableWidget()
        self.table_reports.setColumnCount(2)
        self.table_reports.setRowCount(0)
        self.table_reports.setHorizontalHeaderLabels(["Category", "Total Quantity"])
        self.table_reports.horizontalHeader().setSectionResizeMode(0, QtWidgets.QHeaderView.Stretch)
        self.table_reports.horizontalHeader().setSectionResizeMode(1, QtWidgets.QHeaderView.Stretch)
        self.table_reports.setEditTriggers(QtWidgets.QAbstractItemView.NoEditTriggers)
        self.table_reports.verticalHeader().setVisible(False)
        table_v.addWidget(self.table_reports)
        page_layout.addWidget(table_card)

        # Import / Export buttons
        export_row = QtWidgets.QHBoxLayout()
        export_row.setSpacing(10)
        export_row.addStretch()
        self.btn_import = QtWidgets.QPushButton("⬆  Import Inventory (CSV)")
        self.btn_import.setObjectName("btnExport")
        self.btn_import.setCursor(QtGui.QCursor(QtCore.Qt.PointingHandCursor))
        self.btn_import.setFixedHeight(40)
        self.btn_export = QtWidgets.QPushButton("⬇  Export Report (CSV)")
        self.btn_export.setObjectName("btnExport")
        self.btn_export.setCursor(QtGui.QCursor(QtCore.Qt.PointingHandCursor))
        self.btn_export.setFixedHeight(40)
        self.btn_export_pdf = QtWidgets.QPushButton("📄 Export PDF Report")
        self.btn_export_pdf.setObjectName("btnSecondary")
        self.btn_export_pdf.setCursor(QtGui.QCursor(QtCore.Qt.PointingHandCursor))
        self.btn_export_pdf.setFixedHeight(40)
        export_row.addWidget(self.btn_import)
        export_row.addWidget(self.btn_export_pdf)
        export_row.addWidget(self.btn_export)
        page_layout.addLayout(export_row)

        self.stackedWidget.addWidget(self.page_reports)

    def _kpi_card(self, label_text, value_text, icon, value_object_name):
        """Creates a KPI metric card and returns the value QLabel."""
        if not hasattr(self, '_kpi_boxes'):
            self._kpi_boxes = []

        card = QtWidgets.QFrame()
        card.setObjectName("card")
        card.setMinimumHeight(110)
        v = QtWidgets.QVBoxLayout(card)
        v.setContentsMargins(18, 14, 18, 14)
        v.setSpacing(6)

        top_row = QtWidgets.QHBoxLayout()
        lbl = QtWidgets.QLabel(label_text)
        lbl.setObjectName("kpiCardLabel")
        icon_lbl = QtWidgets.QLabel(icon)
        icon_lbl.setObjectName("kpiCardIcon")
        top_row.addWidget(lbl)
        top_row.addStretch()
        top_row.addWidget(icon_lbl)
        v.addLayout(top_row)

        value_lbl = QtWidgets.QLabel(value_text)
        value_lbl.setObjectName(value_object_name)
        v.addWidget(value_lbl)

        self._kpi_boxes.append(card)
        return value_lbl

    # ─────────────────────────────────────────────────────────────────
    #  PAGE 3 – System Settings
    # ─────────────────────────────────────────────────────────────────
    def _build_settings_page(self):
        self.page_settings = QtWidgets.QWidget()
        outer = QtWidgets.QHBoxLayout(self.page_settings)
        outer.setContentsMargins(0, 0, 0, 0)
        outer.setSpacing(0)

        # ── Left sidebar ──────────────────────────────────────────────
        sidebar = QtWidgets.QFrame()
        sidebar.setObjectName("settingsSidebar")
        sidebar.setFixedWidth(220)
        sb_layout = QtWidgets.QVBoxLayout(sidebar)
        sb_layout.setContentsMargins(12, 16, 12, 16)
        sb_layout.setSpacing(4)

        # Workspace badge
        ws_frame = QtWidgets.QFrame()
        ws_frame.setObjectName("wsBadgeRow")
        ws_row = QtWidgets.QHBoxLayout(ws_frame)
        ws_row.setSpacing(10)
        ws_icon = QtWidgets.QLabel("W")
        ws_icon.setFixedSize(38, 38)
        ws_icon.setAlignment(QtCore.Qt.AlignCenter)
        ws_icon.setObjectName("wsBadgeIcon")
        ws_text_col = QtWidgets.QVBoxLayout()
        ws_title = QtWidgets.QLabel("Inventory Ops")
        ws_title.setObjectName("wsBadgeTitle")
        ws_sub = QtWidgets.QLabel("Warehouse A-12")
        ws_sub.setObjectName("wsBadgeSubtitle")
        ws_text_col.addWidget(ws_title)
        ws_text_col.addWidget(ws_sub)
        ws_row.addWidget(ws_icon)
        ws_row.addLayout(ws_text_col)
        sb_layout.addWidget(ws_frame)
        sb_layout.addSpacing(12)

        sb_layout.addStretch()

        outer.addWidget(sidebar)

        # ── Main settings content ──────────────────────────────────────
        scroll = QtWidgets.QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QtWidgets.QFrame.NoFrame)
        content_widget = QtWidgets.QWidget()
        content_layout = QtWidgets.QVBoxLayout(content_widget)
        content_layout.setContentsMargins(28, 24, 28, 28)
        content_layout.setSpacing(24)

        pg_title = QtWidgets.QLabel("System Settings")
        pg_title.setObjectName("settingsPageTitle")
        pg_sub = QtWidgets.QLabel(
            "Configure environment-level parameters and visual preferences for SmartStock Inventory System."
        )
        pg_sub.setObjectName("settingsPageSubtitle")
        pg_sub.setWordWrap(True)
        content_layout.addWidget(pg_title)
        content_layout.addWidget(pg_sub)

        # ── Database Connection ──────────────────────────────────────
        self.groupBox = QtWidgets.QGroupBox("🗄  Database Connection")
        gb1_layout = QtWidgets.QVBoxLayout(self.groupBox)
        gb1_layout.setSpacing(10)

        db_path_lbl = QtWidgets.QLabel("Read-only Database Path")
        db_path_lbl.setObjectName("inputLabel")
        self.txt_db_path = QtWidgets.QLineEdit()
        self.txt_db_path.setObjectName("readonlyDbPath")
        self.txt_db_path.setReadOnly(True)
        path_note = QtWidgets.QLabel("System-managed path. Contact infrastructure team for migration requests.")
        path_note.setObjectName("mutedNote")
        path_note.setWordWrap(True)

        backup_row = QtWidgets.QHBoxLayout()
        backup_row.addStretch()
        self.btn_backup = QtWidgets.QPushButton("  Backup Database")
        self.btn_backup.setObjectName("btnSettingsPrimary")
        self.btn_backup.setCursor(QtGui.QCursor(QtCore.Qt.PointingHandCursor))
        backup_row.addWidget(self.btn_backup)

        gb1_layout.addWidget(db_path_lbl)
        gb1_layout.addWidget(self.txt_db_path)
        gb1_layout.addWidget(path_note)
        gb1_layout.addLayout(backup_row)
        content_layout.addWidget(self.groupBox)

        # ── Appearance ───────────────────────────────────────────────
        self.groupBox_2 = QtWidgets.QGroupBox("🎨  Appearance")
        gb2_layout = QtWidgets.QGridLayout(self.groupBox_2)
        gb2_layout.setSpacing(14)

        theme_lbl = QtWidgets.QLabel("Theme")
        theme_lbl.setObjectName("inputLabel")
        self.combo_theme = QtWidgets.QComboBox()
        self.combo_theme.setFixedHeight(36)

        self.chk_dark_mode = QtWidgets.QCheckBox("Enable Dark Mode")
        dark_note = QtWidgets.QLabel("Forces high-contrast dark theme across all modules.")
        dark_note.setObjectName("mutedNote")

        gb2_layout.addWidget(theme_lbl, 0, 0)
        gb2_layout.addWidget(self.combo_theme, 1, 0)
        gb2_layout.addWidget(self.chk_dark_mode, 0, 1)
        gb2_layout.addWidget(dark_note, 1, 1)
        content_layout.addWidget(self.groupBox_2)

        # ── Category Management ──────────────────────────────────────
        self.groupBox_3 = QtWidgets.QGroupBox("🏷  Category Management")
        gb3_layout = QtWidgets.QVBoxLayout(self.groupBox_3)
        gb3_layout.setSpacing(10)

        add_row = QtWidgets.QHBoxLayout()
        cat_lbl = QtWidgets.QLabel("New Category Name")
        cat_lbl.setObjectName("inputLabel")
        self.input_new_category = QtWidgets.QLineEdit()
        self.input_new_category.setPlaceholderText("e.g. Consumables")
        self.input_new_category.setFixedHeight(36)
        self.btn_add_category = QtWidgets.QPushButton("+ Add Category")
        self.btn_add_category.setObjectName("btnCategoryAdd")
        self.btn_add_category.setFixedHeight(36)
        self.btn_add_category.setCursor(QtGui.QCursor(QtCore.Qt.PointingHandCursor))
        add_row.addWidget(self.input_new_category)
        add_row.addWidget(self.btn_add_category)

        self.list_categories = QtWidgets.QListWidget()
        self.list_categories.setMinimumHeight(130)

        self.btn_remove_category = QtWidgets.QPushButton("Remove Selected Category")
        self.btn_remove_category.setObjectName("btnCategoryRemove")
        self.btn_remove_category.setCursor(QtGui.QCursor(QtCore.Qt.PointingHandCursor))
        self.btn_remove_category.setFixedHeight(36)

        gb3_layout.addWidget(cat_lbl)
        gb3_layout.addLayout(add_row)
        gb3_layout.addWidget(self.list_categories)
        gb3_layout.addWidget(self.btn_remove_category)
        content_layout.addWidget(self.groupBox_3)

        # ── Danger Zone ──────────────────────────────────────────────
        danger_frame = QtWidgets.QFrame()
        danger_frame.setObjectName("dangerZone")
        danger_layout = QtWidgets.QHBoxLayout(danger_frame)
        danger_layout.setContentsMargins(20, 16, 20, 16)
        danger_layout.setSpacing(16)

        danger_text_col = QtWidgets.QVBoxLayout()
        danger_title = QtWidgets.QLabel("Danger Zone")
        danger_title.setObjectName("dangerTitle")
        danger_desc = QtWidgets.QLabel(
            "Performing a factory reset will erase all local inventory data. "
            "This action is irreversible."
        )
        danger_desc.setObjectName("dangerDesc")
        danger_desc.setWordWrap(True)
        danger_text_col.addWidget(danger_title)
        danger_text_col.addWidget(danger_desc)

        self.btn_reset_all = QtWidgets.QPushButton("🗑  Reset All Data")
        self.btn_reset_all.setObjectName("btnDanger")
        self.btn_reset_all.setCursor(QtGui.QCursor(QtCore.Qt.PointingHandCursor))
        self.btn_reset_all.setFixedHeight(40)

        danger_layout.addLayout(danger_text_col)
        danger_layout.addStretch()
        danger_layout.addWidget(self.btn_reset_all)
        content_layout.addWidget(danger_frame)
        content_layout.addStretch()

        scroll.setWidget(content_widget)
        outer.addWidget(scroll)
        self.stackedWidget.addWidget(self.page_settings)

    # ─────────────────────────────────────────────────────────────────
    #  PAGE 4 – Audit Log (Global Timeline)
    # ─────────────────────────────────────────────────────────────────
    def _build_audit_page(self):
        self.page_audit = QtWidgets.QWidget()
        page_layout = QtWidgets.QVBoxLayout(self.page_audit)
        page_layout.setContentsMargins(28, 20, 28, 20)
        page_layout.setSpacing(16)

        # ── Page title row ────────────────────────────────────────────
        title_col = QtWidgets.QVBoxLayout()
        audit_page_title = QtWidgets.QLabel("Audit Trail")
        audit_page_title.setObjectName("reportPageTitle")
        audit_page_sub = QtWidgets.QLabel(
            "Immutable, time-ordered record of every stock movement across all items."
        )
        audit_page_sub.setObjectName("reportPageSubtitle")
        title_col.addWidget(audit_page_title)
        title_col.addWidget(audit_page_sub)

        title_row = QtWidgets.QHBoxLayout()
        title_row.addLayout(title_col)
        title_row.addStretch()
        self.btn_audit_export = QtWidgets.QPushButton("⬇  Export Ledger (CSV)")
        self.btn_audit_export.setObjectName("btnExport")
        self.btn_audit_export.setCursor(QtGui.QCursor(QtCore.Qt.PointingHandCursor))
        self.btn_audit_export.setFixedHeight(38)
        title_row.addWidget(self.btn_audit_export)
        page_layout.addLayout(title_row)

        # ── Filter bar card ───────────────────────────────────────────
        filter_card = QtWidgets.QFrame()
        filter_card.setObjectName("card")
        filter_layout = QtWidgets.QHBoxLayout(filter_card)
        filter_layout.setContentsMargins(16, 12, 16, 12)
        filter_layout.setSpacing(12)

        filter_lbl = QtWidgets.QLabel("🔍")
        filter_lbl.setObjectName("kpiCardIcon")

        item_filter_lbl = QtWidgets.QLabel("Item")
        item_filter_lbl.setObjectName("inputLabel")
        self.audit_combo_item = QtWidgets.QComboBox()
        self.audit_combo_item.setMinimumWidth(180)
        self.audit_combo_item.setFixedHeight(34)
        self.audit_combo_item.addItem("All Items")

        type_filter_lbl = QtWidgets.QLabel("Change Type")
        type_filter_lbl.setObjectName("inputLabel")
        self.audit_combo_type = QtWidgets.QComboBox()
        self.audit_combo_type.setMinimumWidth(140)
        self.audit_combo_type.setFixedHeight(34)
        for tag in ("All Types", "CREATE", "MANUAL_EDIT", "CSV_IMPORT", "RESTOCK", "DISPENSE"):
            self.audit_combo_type.addItem(tag)

        from_lbl = QtWidgets.QLabel("From")
        from_lbl.setObjectName("inputLabel")
        self.audit_date_from = QtWidgets.QDateEdit()
        self.audit_date_from.setCalendarPopup(True)
        self.audit_date_from.setFixedHeight(34)
        self.audit_date_from.setDate(QtCore.QDate.currentDate().addDays(-30))
        self.audit_date_from.setDisplayFormat("yyyy-MM-dd")

        to_lbl = QtWidgets.QLabel("To")
        to_lbl.setObjectName("inputLabel")
        self.audit_date_to = QtWidgets.QDateEdit()
        self.audit_date_to.setCalendarPopup(True)
        self.audit_date_to.setFixedHeight(34)
        self.audit_date_to.setDate(QtCore.QDate.currentDate())
        self.audit_date_to.setDisplayFormat("yyyy-MM-dd")

        self.btn_audit_filter = QtWidgets.QPushButton("Apply")
        self.btn_audit_filter.setObjectName("btnPrimary")
        self.btn_audit_filter.setCursor(QtGui.QCursor(QtCore.Qt.PointingHandCursor))
        self.btn_audit_filter.setFixedHeight(34)

        self.btn_audit_clear = QtWidgets.QPushButton("Clear")
        self.btn_audit_clear.setObjectName("btnSecondary")
        self.btn_audit_clear.setCursor(QtGui.QCursor(QtCore.Qt.PointingHandCursor))
        self.btn_audit_clear.setFixedHeight(34)

        filter_layout.addWidget(filter_lbl)
        filter_layout.addWidget(item_filter_lbl)
        filter_layout.addWidget(self.audit_combo_item)
        filter_layout.addWidget(type_filter_lbl)
        filter_layout.addWidget(self.audit_combo_type)
        filter_layout.addWidget(from_lbl)
        filter_layout.addWidget(self.audit_date_from)
        filter_layout.addWidget(to_lbl)
        filter_layout.addWidget(self.audit_date_to)
        filter_layout.addWidget(self.btn_audit_filter)
        filter_layout.addWidget(self.btn_audit_clear)
        filter_layout.addStretch()
        page_layout.addWidget(filter_card)

        # ── Ledger table card ─────────────────────────────────────────
        table_card = QtWidgets.QFrame()
        table_card.setObjectName("card")
        table_v = QtWidgets.QVBoxLayout(table_card)
        table_v.setContentsMargins(0, 0, 0, 0)
        table_v.setSpacing(0)

        th = QtWidgets.QFrame()
        th.setObjectName("cardHeader")
        th.setFixedHeight(52)
        th_layout = QtWidgets.QHBoxLayout(th)
        th_layout.setContentsMargins(20, 10, 20, 10)
        th_title = QtWidgets.QLabel("Stock Movement Ledger")
        th_title.setObjectName("sectionTitle")
        self.lbl_audit_meta = QtWidgets.QLabel("TABLE: InventoryLedger")
        self.lbl_audit_meta.setObjectName("tableMetaBadge")
        th_layout.addWidget(th_title)
        th_layout.addWidget(self.lbl_audit_meta)
        th_layout.addStretch()
        table_v.addWidget(th)

        self.tableAudit = QtWidgets.QTableWidget()
        self.tableAudit.setColumnCount(7)
        self.tableAudit.setHorizontalHeaderLabels([
            "Timestamp (UTC)", "Item Name", "SKU",
            "Change Type", "Δ Quantity", "Price Snapshot", "Running Balance",
        ])
        self.tableAudit.horizontalHeader().setSectionResizeMode(
            0, QtWidgets.QHeaderView.ResizeToContents
        )
        self.tableAudit.horizontalHeader().setSectionResizeMode(
            1, QtWidgets.QHeaderView.Stretch
        )
        self.tableAudit.horizontalHeader().setSectionResizeMode(
            2, QtWidgets.QHeaderView.ResizeToContents
        )
        self.tableAudit.setSelectionMode(QtWidgets.QAbstractItemView.SingleSelection)
        self.tableAudit.setSelectionBehavior(QtWidgets.QAbstractItemView.SelectRows)
        self.tableAudit.setEditTriggers(QtWidgets.QAbstractItemView.NoEditTriggers)
        self.tableAudit.verticalHeader().setVisible(False)
        self.tableAudit.setShowGrid(True)
        self.tableAudit.setAlternatingRowColors(False)
        table_v.addWidget(self.tableAudit)

        # Audit pagination bar
        audit_page_bar = QtWidgets.QFrame()
        audit_page_bar.setObjectName("inventoryActionBar")
        audit_pg_layout = QtWidgets.QHBoxLayout(audit_page_bar)
        audit_pg_layout.setContentsMargins(16, 6, 16, 6)
        audit_pg_layout.setSpacing(10)
        self.btn_audit_prev = QtWidgets.QPushButton("◀ Previous")
        self.btn_audit_prev.setObjectName("btnSecondary")
        self.btn_audit_prev.setCursor(QtGui.QCursor(QtCore.Qt.PointingHandCursor))
        self.lbl_audit_page_info = QtWidgets.QLabel("Page 1 of 1")
        self.lbl_audit_page_info.setObjectName("cardHeaderHint")
        self.btn_audit_next = QtWidgets.QPushButton("Next ▶")
        self.btn_audit_next.setObjectName("btnSecondary")
        self.btn_audit_next.setCursor(QtGui.QCursor(QtCore.Qt.PointingHandCursor))
        audit_pg_layout.addWidget(self.btn_audit_prev)
        audit_pg_layout.addStretch()
        audit_pg_layout.addWidget(self.lbl_audit_page_info)
        audit_pg_layout.addStretch()
        audit_pg_layout.addWidget(self.btn_audit_next)
        table_v.addWidget(audit_page_bar)

        page_layout.addWidget(table_card)
        self.stackedWidget.addWidget(self.page_audit)

    def retranslateUi(self, MainWindow):
        MainWindow.setWindowTitle("SmartStock Inventory System")


# ─────────────────────────────────────────────────────────────────────
#  ITEM HISTORY DIALOG  (Option B – Contextual Drill-Down)
# ─────────────────────────────────────────────────────────────────────
class ItemHistoryDialog(QtWidgets.QDialog):
    """Modal dialog showing the full ledger history for a single inventory item."""

    _RECORDS_PER_PAGE = 50

    def __init__(self, item_id, item_name, sku, db_name, parent=None):
        super().__init__(parent)
        self._item_id   = item_id
        self._item_name = item_name
        self._sku       = sku
        self._db_name   = db_name
        self._page      = 0
        self._total     = 0

        self.setWindowTitle(f"Stock History — {item_name}")
        self.setMinimumSize(820, 560)
        self.setWindowFlags(
            QtCore.Qt.Dialog |
            QtCore.Qt.WindowCloseButtonHint |
            QtCore.Qt.WindowTitleHint
        )

        root = QtWidgets.QVBoxLayout(self)
        root.setContentsMargins(0, 0, 0, 0)
        root.setSpacing(0)

        # ── Header ────────────────────────────────────────────────────
        header = QtWidgets.QFrame()
        header.setObjectName("cardHeader")
        header.setFixedHeight(68)
        h_layout = QtWidgets.QHBoxLayout(header)
        h_layout.setContentsMargins(20, 12, 20, 10)
        h_layout.setSpacing(16)

        icon_lbl = QtWidgets.QLabel("📋")
        icon_lbl.setObjectName("kpiCardIcon")

        title_col = QtWidgets.QVBoxLayout()
        dlg_title = QtWidgets.QLabel(f"Stock History — {item_name}")
        dlg_title.setObjectName("sectionTitle")
        dlg_sub = QtWidgets.QLabel(f"SKU: {sku or '—'}  ·  All recorded movements for this item")
        dlg_sub.setObjectName("sectionSubtitle")
        title_col.addWidget(dlg_title)
        title_col.addWidget(dlg_sub)

        h_layout.addWidget(icon_lbl)
        h_layout.addLayout(title_col)
        h_layout.addStretch()
        root.addWidget(header)

        # ── Summary strip ─────────────────────────────────────────────
        summary_frame = QtWidgets.QFrame()
        summary_frame.setObjectName("card")
        summary_frame.setFixedHeight(56)
        s_layout = QtWidgets.QHBoxLayout(summary_frame)
        s_layout.setContentsMargins(20, 8, 20, 8)
        s_layout.setSpacing(32)

        def _stat(label, obj_name):
            col = QtWidgets.QVBoxLayout()
            col.setSpacing(1)
            lbl = QtWidgets.QLabel(label)
            lbl.setObjectName("inputLabel")
            val = QtWidgets.QLabel("—")
            val.setObjectName(obj_name)
            col.addWidget(lbl)
            col.addWidget(val)
            s_layout.addLayout(col)
            return val

        self.lbl_stat_created   = _stat("First Recorded",  "sectionSubtitle")
        self.lbl_stat_moves     = _stat("Total Movements",  "kpiCardLabel")
        self.lbl_stat_peak      = _stat("Peak Quantity",    "kpiCardLabel")
        self.lbl_stat_current   = _stat("Current Quantity", "kpiValuePrimary")
        s_layout.addStretch()

        self.btn_export_item = QtWidgets.QPushButton("⬇  Export CSV")
        self.btn_export_item.setObjectName("btnSecondary")
        self.btn_export_item.setCursor(QtGui.QCursor(QtCore.Qt.PointingHandCursor))
        self.btn_export_item.setFixedHeight(32)
        s_layout.addWidget(self.btn_export_item)

        root.addWidget(summary_frame)

        # ── Ledger table ──────────────────────────────────────────────
        self.table = QtWidgets.QTableWidget()
        self.table.setColumnCount(5)
        self.table.setHorizontalHeaderLabels([
            "Timestamp (UTC)", "Change Type", "Δ Quantity",
            "Price Snapshot", "Running Balance",
        ])
        self.table.horizontalHeader().setSectionResizeMode(
            0, QtWidgets.QHeaderView.ResizeToContents
        )
        self.table.horizontalHeader().setSectionResizeMode(
            1, QtWidgets.QHeaderView.ResizeToContents
        )
        self.table.horizontalHeader().setSectionResizeMode(
            2, QtWidgets.QHeaderView.ResizeToContents
        )
        self.table.horizontalHeader().setSectionResizeMode(
            3, QtWidgets.QHeaderView.ResizeToContents
        )
        self.table.horizontalHeader().setSectionResizeMode(
            4, QtWidgets.QHeaderView.Stretch
        )
        self.table.setSelectionBehavior(QtWidgets.QAbstractItemView.SelectRows)
        self.table.setEditTriggers(QtWidgets.QAbstractItemView.NoEditTriggers)
        self.table.verticalHeader().setVisible(False)
        self.table.setShowGrid(True)
        root.addWidget(self.table)

        # ── Pagination + close bar ────────────────────────────────────
        footer = QtWidgets.QFrame()
        footer.setObjectName("inventoryActionBar")
        footer.setFixedHeight(52)
        f_layout = QtWidgets.QHBoxLayout(footer)
        f_layout.setContentsMargins(16, 8, 16, 8)
        f_layout.setSpacing(10)

        self.btn_prev = QtWidgets.QPushButton("◀ Previous")
        self.btn_prev.setObjectName("btnSecondary")
        self.btn_prev.setCursor(QtGui.QCursor(QtCore.Qt.PointingHandCursor))
        self.lbl_page = QtWidgets.QLabel("Page 1 of 1")
        self.lbl_page.setObjectName("cardHeaderHint")
        self.btn_next = QtWidgets.QPushButton("Next ▶")
        self.btn_next.setObjectName("btnSecondary")
        self.btn_next.setCursor(QtGui.QCursor(QtCore.Qt.PointingHandCursor))
        btn_close = QtWidgets.QPushButton("Close")
        btn_close.setObjectName("btnSecondary")
        btn_close.setCursor(QtGui.QCursor(QtCore.Qt.PointingHandCursor))
        btn_close.clicked.connect(self.reject)

        f_layout.addWidget(self.btn_prev)
        f_layout.addStretch()
        f_layout.addWidget(self.lbl_page)
        f_layout.addStretch()
        f_layout.addWidget(self.btn_next)
        f_layout.addSpacing(20)
        f_layout.addWidget(btn_close)
        root.addWidget(footer)

        # Wire pagination
        self.btn_prev.clicked.connect(self._go_prev)
        self.btn_next.clicked.connect(self._go_next)

        self._load_summary()
        self._load_page()

    # ── Data loading ──────────────────────────────────────────────────
    def _load_summary(self):
        import sqlite3
        with sqlite3.connect(self._db_name) as conn:
            c = conn.cursor()
            c.execute(
                "SELECT MIN(Timestamp), COUNT(*), "
                "MAX(SUM(DeltaQuantity)) OVER (), "
                "SUM(DeltaQuantity) "
                "FROM InventoryLedger WHERE ItemID=?",
                (self._item_id,),
            )
            row = c.fetchone()
        if row and row[0]:
            created, moves, _, current = row
            # Running peak requires window function scan
            conn2 = sqlite3.connect(self._db_name)
            c2 = conn2.cursor()
            c2.execute(
                "SELECT MAX(run_bal) FROM ("
                "  SELECT SUM(DeltaQuantity) OVER ("
                "    ORDER BY LedgerID ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW"
                "  ) AS run_bal "
                "  FROM InventoryLedger WHERE ItemID=?"
                ")",
                (self._item_id,),
            )
            peak_row = c2.fetchone()
            conn2.close()
            peak = peak_row[0] if peak_row and peak_row[0] is not None else 0
            self.lbl_stat_created.setText(str(created)[:10] if created else "—")
            self.lbl_stat_moves.setText(f"{moves:,}")
            self.lbl_stat_peak.setText(f"{int(peak):,}")
            self.lbl_stat_current.setText(f"{int(current or 0):,}")

    def _load_page(self):
        import sqlite3
        offset = self._page * self._RECORDS_PER_PAGE
        with sqlite3.connect(self._db_name) as conn:
            c = conn.cursor()
            c.execute(
                "SELECT COUNT(*) FROM InventoryLedger WHERE ItemID=?",
                (self._item_id,),
            )
            self._total = c.fetchone()[0]
            c.execute(
                "SELECT Timestamp, ChangeType, DeltaQuantity, PriceSnapshot, "
                "SUM(DeltaQuantity) OVER ("
                "  PARTITION BY ItemID ORDER BY LedgerID "
                "  ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW"
                ") AS RunningBalance "
                "FROM InventoryLedger WHERE ItemID=? "
                "ORDER BY LedgerID DESC "
                "LIMIT ? OFFSET ?",
                (self._item_id, self._RECORDS_PER_PAGE, offset),
            )
            rows = c.fetchall()

        _populate_ledger_table(self.table, rows, show_item_cols=False)

        total_pages = max(1, (self._total + self._RECORDS_PER_PAGE - 1) // self._RECORDS_PER_PAGE)
        if self._page >= total_pages:
            self._page = max(0, total_pages - 1)
        self.lbl_page.setText(
            f"Page {self._page + 1} of {total_pages}  ({self._total:,} entries)"
        )
        self.btn_prev.setEnabled(self._page > 0)
        self.btn_next.setEnabled((self._page + 1) * self._RECORDS_PER_PAGE < self._total)

    def _go_prev(self):
        if self._page > 0:
            self._page -= 1
            self._load_page()

    def _go_next(self):
        if (self._page + 1) * self._RECORDS_PER_PAGE < self._total:
            self._page += 1
            self._load_page()


# ─────────────────────────────────────────────────────────────────────
#  Shared table-population helper (used by both audit views)
# ─────────────────────────────────────────────────────────────────────
_CHANGE_TYPE_ICONS = {
    "CREATE":      "🆕",
    "MANUAL_EDIT": "✏",
    "CSV_IMPORT":  "📥",
    "RESTOCK":     "+",
    "DISPENSE":    "−",
}

def _populate_ledger_table(table_widget, rows, show_item_cols=True):
    """
    Fill a QTableWidget with ledger rows.

    Column layout when show_item_cols=True  (global Audit page, 7 cols):
        Timestamp | Item Name | SKU | Change Type | Δ Qty | Price | Running Balance

    Column layout when show_item_cols=False (per-item dialog, 5 cols):
        Timestamp | Change Type | Δ Qty | Price | Running Balance
    """
    from PyQt5 import QtWidgets, QtGui, QtCore

    COLOR_POS   = QtGui.QColor("#2e7d32")  # green – stock added
    COLOR_NEG   = QtGui.QColor("#ba1a1a")  # red   – stock removed
    COLOR_ZERO  = QtGui.QColor("#737686")  # grey  – price-only change

    table_widget.setRowCount(0)

    for idx, row in enumerate(rows):
        table_widget.insertRow(idx)

        if show_item_cols:
            # row: timestamp, item_name, sku, change_type, delta_qty, price, running_balance
            ts, item_name, sku, change_type, delta_qty, price, running_bal = row
            item_name = item_name or "[Deleted Item]"
            sku       = sku or "—"
            cells = [
                (ts or "—",                                               QtCore.Qt.AlignLeft),
                (item_name,                                               QtCore.Qt.AlignLeft),
                (sku,                                                     QtCore.Qt.AlignLeft),
                (f"{_CHANGE_TYPE_ICONS.get(change_type, '')} {change_type}", QtCore.Qt.AlignLeft),
                (f"{int(delta_qty):+,}" if delta_qty is not None else "—", QtCore.Qt.AlignRight),
                (f"₱{float(price):,.2f}" if price is not None else "—",  QtCore.Qt.AlignRight),
                (f"{int(running_bal):,}" if running_bal is not None else "—", QtCore.Qt.AlignRight),
            ]
        else:
            # row: timestamp, change_type, delta_qty, price, running_balance
            ts, change_type, delta_qty, price, running_bal = row
            cells = [
                (ts or "—",                                               QtCore.Qt.AlignLeft),
                (f"{_CHANGE_TYPE_ICONS.get(change_type, '')} {change_type}", QtCore.Qt.AlignLeft),
                (f"{int(delta_qty):+,}" if delta_qty is not None else "—", QtCore.Qt.AlignRight),
                (f"₱{float(price):,.2f}" if price is not None else "—",  QtCore.Qt.AlignRight),
                (f"{int(running_bal):,}" if running_bal is not None else "—", QtCore.Qt.AlignRight),
            ]

        delta_col_idx = 4 if show_item_cols else 2

        for col, (text, align) in enumerate(cells):
            cell = QtWidgets.QTableWidgetItem(text)
            cell.setTextAlignment(align | QtCore.Qt.AlignVCenter)
            if col == delta_col_idx and delta_qty is not None:
                if int(delta_qty) > 0:
                    cell.setForeground(COLOR_POS)
                elif int(delta_qty) < 0:
                    cell.setForeground(COLOR_NEG)
                else:
                    cell.setForeground(COLOR_ZERO)
            table_widget.setItem(idx, col, cell)


# ── Standalone preview ────────────────────────────────────────────────
if __name__ == "__main__":
    import sys
    app = QtWidgets.QApplication(sys.argv)
    win = QtWidgets.QMainWindow()
    ui = Ui_MainWindow()
    ui.setupUi(win)
    win.show()
    sys.exit(app.exec_())