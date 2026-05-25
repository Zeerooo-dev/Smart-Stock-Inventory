# -*- coding: utf-8 -*-
# SmartStock Inventory System – Application Logic

import sys
import os
import sqlite3
import csv
import shutil
import uuid
from datetime import datetime

from main_window_ui import (
    Ui_MainWindow, BASE_STYLE, COLOR,
    ItemHistoryDialog, _populate_ledger_table,
)
from confirm_dialog_ui import Ui_Dialog
from PyQt5 import QtWidgets, QtCore, QtGui

try:
    from barcode import Code128
    from barcode.writer import ImageWriter
    HAS_BARCODE = True
except ImportError:
    HAS_BARCODE = False

try:
    from matplotlib.backends.backend_qt5agg import FigureCanvasQTAgg as FigureCanvas
    from matplotlib.figure import Figure
    HAS_MPL = True
except ImportError:
    HAS_MPL = False

try:
    from reportlab.lib import colors as rl_colors
    from reportlab.lib.pagesizes import letter
    from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
    from reportlab.lib.units import inch
    from reportlab.platypus import SimpleDocTemplate, Table, TableStyle, Paragraph, Spacer
    HAS_REPORTLAB = True
except ImportError:
    HAS_REPORTLAB = False

BARCODE_DIR = "barcode_labels"

# Matplotlib palettes aligned with each Qt theme (not only Default COLOR tokens)
THEME_CHART_COLORS = {
    "Default": {
        "background": COLOR["background"],
        "surface": COLOR["surface_container_lowest"],
        "primary": COLOR["primary_container"],
        "error": COLOR["error"],
        "on_surface": COLOR["on_surface"],
        "outline": COLOR["outline_variant"],
        "palette": [
            COLOR["primary_container"],
            COLOR["secondary_container"],
            COLOR["tertiary_container"],
            COLOR["secondary"],
            COLOR["primary"],
            COLOR["on_secondary_container"],
        ],
    },
    "Dark": {
        "background": "#1e1e2e",
        "surface": "#181825",
        "primary": "#89b4fa",
        "error": "#f38ba8",
        "on_surface": "#cdd6f4",
        "outline": "#45475a",
        "palette": ["#89b4fa", "#fab387", "#a6e3a1", "#cba6f7", "#f9e2af", "#585b70"],
    },
    "Blue Steel": {
        "background": "#1a2332",
        "surface": "#111b27",
        "primary": "#5ba3d9",
        "error": "#ff8a8a",
        "on_surface": "#e0e8f0",
        "outline": "#2e4057",
        "palette": ["#5ba3d9", "#e6b35c", "#3d7ab5", "#8aaccc", "#2e5b8a", "#1e3a5f"],
    },
    "Forest Green": {
        "background": "#1a2b1a",
        "surface": "#111b11",
        "primary": "#5cb85c",
        "error": "#ff9b9b",
        "on_surface": "#d4e8d0",
        "outline": "#2e4f2e",
        "palette": ["#5cb85c", "#d4a84b", "#3d8a3d", "#8ab88a", "#2e6b2e", "#1e3d1e"],
    },
}


# ─────────────────────────────────────────────────────────────────────
#  THEME DEFINITIONS
# ─────────────────────────────────────────────────────────────────────
THEMES = {
    "Default": BASE_STYLE,

    "Dark": """
        QMainWindow, QWidget, QDialog {
            background-color: #1e1e2e; color: #cdd6f4;
            font-family: 'Inter', 'Segoe UI', sans-serif; font-size: 14px;
        }
        QFrame#topNavBar { background-color:#181825; border-bottom:1px solid #45475a; }
        QLabel#appTitle  { font-size:18px; font-weight:700; color:#b4c5ff; }
        QPushButton#navBtn {
            background:transparent; border:none; color:#a6adc8;
            font-size:14px; padding:4px 12px; border-bottom:2px solid transparent;
        }
        QPushButton#navBtn:hover { color:#cdd6f4; }
        QPushButton#navBtnActive {
            background:transparent; border:none; border-bottom:2px solid #b4c5ff;
            color:#b4c5ff; font-size:14px; font-weight:700; padding:4px 12px;
        }
        QFrame#card { background-color:#181825; border:1px solid #45475a; border-radius:8px; }
        QFrame#cardHeader {
            background-color:#1e1e2e; border-bottom:1px solid #45475a;
            border-top-left-radius:8px; border-top-right-radius:8px;
        }
        QLabel#sectionTitle    { font-size:16px; font-weight:600; color:#cdd6f4; }
        QLabel#sectionSubtitle { font-size:12px; color:#a6adc8; }
        QLabel#inputLabel      { font-size:13px; font-weight:600; color:#a6adc8; }
        QLineEdit, QSpinBox, QDoubleSpinBox, QComboBox {
            background-color:#313244; color:#cdd6f4;
            border:1px solid #45475a; border-radius:6px; padding:6px 10px;
            font-size:14px;
        }
        QComboBox QAbstractItemView { background-color:#313244; color:#cdd6f4; selection-background-color:#585b70; }
        QPushButton#btnPrimary {
            background-color:#585b70; color:#cdd6f4; border:none;
            border-radius:6px; font-size:13px; font-weight:600; padding:10px 16px;
        }
        QPushButton#btnPrimary:hover { background-color:#6c6f85; }
        QPushButton#btnSecondary {
            background-color:transparent; color:#a6adc8; border:1px solid #45475a;
            border-radius:6px; font-size:13px; font-weight:600; padding:10px 16px;
        }
        QPushButton#btnSecondary:hover { background-color:#313244; }
        QPushButton#btnUpdate {
            background-color:#313244; color:#cdd6f4; border:none;
            border-radius:6px; font-size:13px; font-weight:600; padding:8px 16px;
        }
        QPushButton#btnUpdate:hover { background-color:#45475a; }
        QPushButton#btnDelete {
            background-color:#3b1a1a; color:#f38ba8; border:none;
            border-radius:6px; font-size:13px; font-weight:600; padding:8px 16px;
        }
        QPushButton#btnDelete:hover { background-color:#562222; }
        QTableWidget {
            background-color:#181825; color:#cdd6f4; gridline-color:#45475a;
            border:none; selection-background-color:#313244;
            font-size:14px;
        }
        QHeaderView::section {
            background-color:#313244; color:#89b4fa;
            font-size:13px; font-weight:600; padding:10px 16px;
            border:none; border-bottom:1px solid #45475a;
        }
        QTableWidget::item { padding:8px 16px; }
        QTableWidget::item:hover { background-color:#313244; }
        QListWidget {
            background-color:#181825; color:#cdd6f4;
            border:1px solid #45475a; border-radius:6px;
            font-size:14px;
        }
        QListWidget::item { padding:6px 12px; }
        QListWidget::item:selected { background-color:#585b70; }
        QListWidget::item:hover    { background-color:#313244; }
        QGroupBox {
            background-color:#181825; border:1px solid #45475a; border-radius:10px;
            margin-top:16px; padding:12px; font-size:15px; font-weight:600; color:#cdd6f4;
        }
        QGroupBox::title { color:#cdd6f4; left:14px; padding:0 6px; }
        QPushButton#btnSettingsPrimary {
            background-color:#585b70; color:#cdd6f4; border:none;
            border-radius:6px; font-size:13px; font-weight:600; padding:10px 20px;
        }
        QPushButton#btnSettingsPrimary:hover { background-color:#6c6f85; }
        QPushButton#btnDanger {
            background-color:#a6303b; color:#ffffff; border:none;
            border-radius:6px; font-size:13px; font-weight:600; padding:10px 20px;
        }
        QPushButton#btnDanger:hover { background-color:#d04050; }
        QPushButton#btnCategoryAdd {
            background-color:#313244; color:#cdd6f4; border:none;
            border-radius:6px; font-size:13px; font-weight:600; padding:8px 14px;
        }
        QPushButton#btnCategoryAdd:hover { background-color:#45475a; }
        QPushButton#btnCategoryRemove {
            background-color:#3b1a1a; color:#f38ba8; border:none;
            border-radius:6px; font-size:13px; font-weight:600; padding:8px 14px;
        }
        QPushButton#btnCategoryRemove:hover { background-color:#562222; }
        QPushButton#btnExport {
            background-color:#585b70; color:#cdd6f4; border:none;
            border-radius:6px; font-size:13px; font-weight:600; padding:10px 20px;
        }
        QPushButton#btnExport:hover { background-color:#6c6f85; }
        QStatusBar { background-color:#181825; color:#a6adc8; border-top:1px solid #45475a; font-size:12px; }
        QCheckBox { font-size:14px; font-weight:600; color:#cdd6f4; }
        QCheckBox::indicator {
            width:18px; height:18px; border:2px solid #45475a; border-radius:4px; background:#313244;
        }
        QCheckBox::indicator:checked { background-color:#b4c5ff; border-color:#b4c5ff; }
        QScrollBar:vertical { background:#181825; width:8px; border-radius:4px; }
        QScrollBar::handle:vertical { background:#45475a; border-radius:4px; min-height:20px; }
        QScrollBar::add-line:vertical, QScrollBar::sub-line:vertical { height:0px; }

        QFrame#settingsSidebar { background-color:#181825; border-right:1px solid #45475a; }
        QFrame#inventoryActionBar { background-color:#181825; border-top:1px solid #45475a; }
        QLabel#tableMetaBadge {
            background-color:#313244; color:#a6adc8; font-size:11px; font-weight:700;
            letter-spacing:0.06em; padding:2px 8px; border-radius:4px;
        }
        QLabel#reportPageTitle { font-size:26px; font-weight:700; color:#cdd6f4; }
        QLabel#reportPageSubtitle { font-size:14px; color:#a6adc8; }
        QLabel#settingsPageTitle { font-size:26px; font-weight:700; color:#cdd6f4; }
        QLabel#settingsPageSubtitle { font-size:14px; color:#a6adc8; }
        QLabel#cardHeaderHint { font-size:12px; color:#a6adc8; }
        QLabel#kpiCardLabel { font-size:13px; font-weight:600; color:#a6adc8; }
        QLabel#kpiCardIcon { font-size:20px; }
        QLabel#kpiValuePrimary { font-size:28px; font-weight:700; color:#89b4fa; }
        QLabel#kpiValueMoney { font-size:28px; font-weight:700; color:#fab387; }
        QLabel#kpiValueAlert[alert="true"] { font-size:28px; font-weight:700; color:#f38ba8; }
        QLabel#kpiValueAlert[alert="false"] { font-size:28px; font-weight:700; color:#cdd6f4; }
        QLabel#wsBadgeIcon {
            background-color:#313244; color:#cdd6f4; border-radius:19px;
            font-weight:700; font-size:15px;
        }
        QLabel#wsBadgeTitle { font-weight:700; font-size:14px; color:#cdd6f4; background:transparent; }
        QLabel#wsBadgeSubtitle { font-size:12px; color:#a6adc8; background:transparent; }
        QFrame#wsBadgeRow { background:transparent; border:none; }
        QLineEdit#readonlyDbPath {
            background-color:#313244; color:#cdd6f4; border:1px solid #45475a;
            border-radius:6px; padding:8px 12px;
            font-family:'JetBrains Mono','Consolas',monospace; font-size:13px;
        }
        QLabel#mutedNote { font-size:12px; color:#a6adc8; }
        QFrame#dangerZone {
            background-color:rgba(243,139,168,0.08); border:1px solid rgba(243,139,168,0.35);
            border-radius:10px;
        }
        QLabel#dangerTitle { font-size:13px; font-weight:600; color:#f38ba8; background:transparent; }
        QLabel#dangerDesc { font-size:12px; color:#a6adc8; background:transparent; }
    """,

    "Blue Steel": """
        QMainWindow, QWidget, QDialog {
            background-color: #1a2332; color: #e0e8f0;
            font-family: 'Inter', 'Segoe UI', sans-serif; font-size: 14px;
        }
        QFrame#topNavBar { background-color:#111b27; border-bottom:1px solid #2e4057; }
        QLabel#appTitle  { font-size:18px; font-weight:700; color:#5ba3d9; }
        QPushButton#navBtn {
            background:transparent; border:none; color:#8aaccc;
            font-size:14px; padding:4px 12px; border-bottom:2px solid transparent;
        }
        QPushButton#navBtn:hover { color:#e0e8f0; }
        QPushButton#navBtnActive {
            background:transparent; border:none; border-bottom:2px solid #5ba3d9;
            color:#5ba3d9; font-size:14px; font-weight:700; padding:4px 12px;
        }
        QFrame#card { background-color:#111b27; border:1px solid #2e4057; border-radius:8px; }
        QFrame#cardHeader {
            background-color:#1a2332; border-bottom:1px solid #2e4057;
            border-top-left-radius:8px; border-top-right-radius:8px;
        }
        QLabel#sectionTitle    { font-size:16px; font-weight:600; color:#e0e8f0; }
        QLabel#sectionSubtitle { font-size:12px; color:#8aaccc; }
        QLabel#inputLabel      { font-size:13px; font-weight:600; color:#8aaccc; }
        QLineEdit, QSpinBox, QDoubleSpinBox, QComboBox {
            background-color:#1e3a5f; color:#e0e8f0;
            border:1px solid #2e5b8a; border-radius:6px; padding:6px 10px;
            font-size:14px;
        }
        QComboBox QAbstractItemView { background-color:#1e3a5f; color:#e0e8f0; selection-background-color:#2e5b8a; }
        QPushButton#btnPrimary {
            background-color:#2e5b8a; color:#e0e8f0; border:none;
            border-radius:6px; font-size:13px; font-weight:600; padding:10px 16px;
        }
        QPushButton#btnPrimary:hover { background-color:#3d7ab5; }
        QPushButton#btnSecondary {
            background-color:transparent; color:#8aaccc; border:1px solid #2e4057;
            border-radius:6px; font-size:13px; font-weight:600; padding:10px 16px;
        }
        QPushButton#btnSecondary:hover { background-color:#1e3a5f; }
        QPushButton#btnUpdate {
            background-color:#1e3a5f; color:#e0e8f0; border:none;
            border-radius:6px; font-size:13px; font-weight:600; padding:8px 16px;
        }
        QPushButton#btnUpdate:hover { background-color:#2e5b8a; }
        QPushButton#btnDelete {
            background-color:#3b1a1a; color:#f38ba8; border:none;
            border-radius:6px; font-size:13px; font-weight:600; padding:8px 16px;
        }
        QPushButton#btnDelete:hover { background-color:#562222; }
        QTableWidget {
            background-color:#111b27; color:#e0e8f0; gridline-color:#2e4057;
            border:none; selection-background-color:#1e3a5f;
            font-size:14px;
        }
        QHeaderView::section {
            background-color:#1e3a5f; color:#5ba3d9;
            font-size:13px; font-weight:600; padding:10px 16px;
            border:none; border-bottom:1px solid #2e5b8a;
        }
        QTableWidget::item { padding:8px 16px; }
        QTableWidget::item:hover { background-color:#1e3a5f; }
        QListWidget { background-color:#111b27; color:#e0e8f0; border:1px solid #2e4057; border-radius:6px; font-size:14px; }
        QListWidget::item { padding:6px 12px; }
        QListWidget::item:selected { background-color:#2e5b8a; }
        QListWidget::item:hover { background-color:#1e3a5f; }
        QGroupBox {
            background-color:#111b27; border:1px solid #2e4057; border-radius:10px;
            margin-top:16px; padding:12px; font-size:15px; font-weight:600; color:#e0e8f0;
        }
        QGroupBox::title { color:#e0e8f0; left:14px; padding:0 6px; }
        QPushButton#btnSettingsPrimary { background-color:#2e5b8a; color:#e0e8f0; border:none; border-radius:6px; font-size:13px; font-weight:600; padding:10px 20px; }
        QPushButton#btnDanger          { background-color:#8b1a2e; color:#ffffff; border:none; border-radius:6px; font-size:13px; font-weight:600; padding:10px 20px; }
        QPushButton#btnCategoryAdd     { background-color:#2e5b8a; color:#e0e8f0; border:none; border-radius:6px; font-size:13px; font-weight:600; padding:8px 14px; }
        QPushButton#btnCategoryRemove  { background-color:#3b1a1a; color:#f38ba8; border:none; border-radius:6px; font-size:13px; font-weight:600; padding:8px 14px; }
        QPushButton#btnExport          { background-color:#2e5b8a; color:#e0e8f0; border:none; border-radius:6px; font-size:13px; font-weight:600; padding:10px 20px; }
        QStatusBar { background-color:#111b27; color:#8aaccc; border-top:1px solid #2e4057; font-size:12px; }
        QCheckBox { font-size:14px; font-weight:600; color:#e0e8f0; }
        QCheckBox::indicator { width:18px; height:18px; border:2px solid #2e4057; border-radius:4px; background:#1e3a5f; }
        QCheckBox::indicator:checked { background-color:#5ba3d9; border-color:#5ba3d9; }
        QScrollBar:vertical { background:#111b27; width:8px; border-radius:4px; }
        QScrollBar::handle:vertical { background:#2e4057; border-radius:4px; min-height:20px; }
        QScrollBar::add-line:vertical, QScrollBar::sub-line:vertical { height:0px; }

        QFrame#settingsSidebar { background-color:#111b27; border-right:1px solid #2e4057; }
        QFrame#inventoryActionBar { background-color:#111b27; border-top:1px solid #2e4057; }
        QLabel#tableMetaBadge {
            background-color:#1e3a5f; color:#8aaccc; font-size:11px; font-weight:700;
            letter-spacing:0.06em; padding:2px 8px; border-radius:4px;
        }
        QLabel#reportPageTitle { font-size:26px; font-weight:700; color:#e0e8f0; }
        QLabel#reportPageSubtitle { font-size:14px; color:#8aaccc; }
        QLabel#settingsPageTitle { font-size:26px; font-weight:700; color:#e0e8f0; }
        QLabel#settingsPageSubtitle { font-size:14px; color:#8aaccc; }
        QLabel#cardHeaderHint { font-size:12px; color:#8aaccc; }
        QLabel#kpiCardLabel { font-size:13px; font-weight:600; color:#8aaccc; }
        QLabel#kpiCardIcon { font-size:20px; }
        QLabel#kpiValuePrimary { font-size:28px; font-weight:700; color:#5ba3d9; }
        QLabel#kpiValueMoney { font-size:28px; font-weight:700; color:#e6b35c; }
        QLabel#kpiValueAlert[alert="true"] { font-size:28px; font-weight:700; color:#ff8a8a; }
        QLabel#kpiValueAlert[alert="false"] { font-size:28px; font-weight:700; color:#e0e8f0; }
        QLabel#wsBadgeIcon {
            background-color:#1e3a5f; color:#e0e8f0; border-radius:19px;
            font-weight:700; font-size:15px;
        }
        QLabel#wsBadgeTitle { font-weight:700; font-size:14px; color:#e0e8f0; background:transparent; }
        QLabel#wsBadgeSubtitle { font-size:12px; color:#8aaccc; background:transparent; }
        QFrame#wsBadgeRow { background:transparent; border:none; }
        QLineEdit#readonlyDbPath {
            background-color:#1e3a5f; color:#e0e8f0; border:1px solid #2e5b8a;
            border-radius:6px; padding:8px 12px;
            font-family:'JetBrains Mono','Consolas',monospace; font-size:13px;
        }
        QLabel#mutedNote { font-size:12px; color:#8aaccc; }
        QFrame#dangerZone {
            background-color:rgba(255,107,107,0.08); border:1px solid rgba(255,107,107,0.35);
            border-radius:10px;
        }
        QLabel#dangerTitle { font-size:13px; font-weight:600; color:#ff8a8a; background:transparent; }
        QLabel#dangerDesc { font-size:12px; color:#8aaccc; background:transparent; }
    """,

    "Forest Green": """
        QMainWindow, QWidget, QDialog {
            background-color: #1a2b1a; color: #d4e8d0;
            font-family: 'Inter', 'Segoe UI', sans-serif; font-size: 14px;
        }
        QFrame#topNavBar { background-color:#111b11; border-bottom:1px solid #2e4f2e; }
        QLabel#appTitle  { font-size:18px; font-weight:700; color:#5cb85c; }
        QPushButton#navBtn {
            background:transparent; border:none; color:#8ab88a;
            font-size:14px; padding:4px 12px; border-bottom:2px solid transparent;
        }
        QPushButton#navBtn:hover { color:#d4e8d0; }
        QPushButton#navBtnActive {
            background:transparent; border:none; border-bottom:2px solid #5cb85c;
            color:#5cb85c; font-size:14px; font-weight:700; padding:4px 12px;
        }
        QFrame#card { background-color:#111b11; border:1px solid #2e4f2e; border-radius:8px; }
        QFrame#cardHeader {
            background-color:#1a2b1a; border-bottom:1px solid #2e4f2e;
            border-top-left-radius:8px; border-top-right-radius:8px;
        }
        QLabel#sectionTitle    { font-size:16px; font-weight:600; color:#d4e8d0; }
        QLabel#sectionSubtitle { font-size:12px; color:#8ab88a; }
        QLabel#inputLabel      { font-size:13px; font-weight:600; color:#8ab88a; }
        QLineEdit, QSpinBox, QDoubleSpinBox, QComboBox {
            background-color:#1e3d1e; color:#d4e8d0;
            border:1px solid #2e6b2e; border-radius:6px; padding:6px 10px;
            font-size:14px;
        }
        QComboBox QAbstractItemView { background-color:#1e3d1e; color:#d4e8d0; selection-background-color:#3d8a3d; }
        QPushButton#btnPrimary { background-color:#2e6b2e; color:#d4e8d0; border:none; border-radius:6px; font-size:13px; font-weight:600; padding:10px 16px; }
        QPushButton#btnPrimary:hover { background-color:#3d8a3d; }
        QPushButton#btnSecondary { background-color:transparent; color:#8ab88a; border:1px solid #2e4f2e; border-radius:6px; font-size:13px; font-weight:600; padding:10px 16px; }
        QPushButton#btnSecondary:hover { background-color:#1e3d1e; }
        QPushButton#btnUpdate { background-color:#1e3d1e; color:#d4e8d0; border:none; border-radius:6px; font-size:13px; font-weight:600; padding:8px 16px; }
        QPushButton#btnUpdate:hover { background-color:#2e6b2e; }
        QPushButton#btnDelete { background-color:#3b1a1a; color:#f38ba8; border:none; border-radius:6px; font-size:13px; font-weight:600; padding:8px 16px; }
        QPushButton#btnDelete:hover { background-color:#562222; }
        QTableWidget { background-color:#111b11; color:#d4e8d0; gridline-color:#2e4f2e; border:none; selection-background-color:#1e3d1e; font-size:14px; }
        QHeaderView::section { background-color:#1e3d1e; color:#5cb85c; font-size:13px; font-weight:600; padding:10px 16px; border:none; border-bottom:1px solid #2e6b2e; }
        QTableWidget::item { padding:8px 16px; }
        QTableWidget::item:hover { background-color:#1e3d1e; }
        QListWidget { background-color:#111b11; color:#d4e8d0; border:1px solid #2e4f2e; border-radius:6px; font-size:14px; }
        QListWidget::item { padding:6px 12px; }
        QListWidget::item:selected { background-color:#2e6b2e; }
        QListWidget::item:hover { background-color:#1e3d1e; }
        QGroupBox { background-color:#111b11; border:1px solid #2e4f2e; border-radius:10px; margin-top:16px; padding:12px; font-size:15px; font-weight:600; color:#d4e8d0; }
        QGroupBox::title { color:#d4e8d0; left:14px; padding:0 6px; }
        QPushButton#btnSettingsPrimary { background-color:#2e6b2e; color:#d4e8d0; border:none; border-radius:6px; font-size:13px; font-weight:600; padding:10px 20px; }
        QPushButton#btnDanger          { background-color:#8b1a1a; color:#ffffff; border:none; border-radius:6px; font-size:13px; font-weight:600; padding:10px 20px; }
        QPushButton#btnCategoryAdd     { background-color:#2e6b2e; color:#d4e8d0; border:none; border-radius:6px; font-size:13px; font-weight:600; padding:8px 14px; }
        QPushButton#btnCategoryRemove  { background-color:#3b1a1a; color:#f38ba8; border:none; border-radius:6px; font-size:13px; font-weight:600; padding:8px 14px; }
        QPushButton#btnExport          { background-color:#2e6b2e; color:#d4e8d0; border:none; border-radius:6px; font-size:13px; font-weight:600; padding:10px 20px; }
        QStatusBar { background-color:#111b11; color:#8ab88a; border-top:1px solid #2e4f2e; font-size:12px; }
        QCheckBox { font-size:14px; font-weight:600; color:#d4e8d0; }
        QCheckBox::indicator { width:18px; height:18px; border:2px solid #2e4f2e; border-radius:4px; background:#1e3d1e; }
        QCheckBox::indicator:checked { background-color:#5cb85c; border-color:#5cb85c; }
        QScrollBar:vertical { background:#111b11; width:8px; border-radius:4px; }
        QScrollBar::handle:vertical { background:#2e4f2e; border-radius:4px; min-height:20px; }
        QScrollBar::add-line:vertical, QScrollBar::sub-line:vertical { height:0px; }

        QFrame#settingsSidebar { background-color:#111b11; border-right:1px solid #2e4f2e; }
        QFrame#inventoryActionBar { background-color:#111b11; border-top:1px solid #2e4f2e; }
        QLabel#tableMetaBadge {
            background-color:#1e3d1e; color:#8ab88a; font-size:11px; font-weight:700;
            letter-spacing:0.06em; padding:2px 8px; border-radius:4px;
        }
        QLabel#reportPageTitle { font-size:26px; font-weight:700; color:#d4e8d0; }
        QLabel#reportPageSubtitle { font-size:14px; color:#8ab88a; }
        QLabel#settingsPageTitle { font-size:26px; font-weight:700; color:#d4e8d0; }
        QLabel#settingsPageSubtitle { font-size:14px; color:#8ab88a; }
        QLabel#cardHeaderHint { font-size:12px; color:#8ab88a; }
        QLabel#kpiCardLabel { font-size:13px; font-weight:600; color:#8ab88a; }
        QLabel#kpiCardIcon { font-size:20px; }
        QLabel#kpiValuePrimary { font-size:28px; font-weight:700; color:#5cb85c; }
        QLabel#kpiValueMoney { font-size:28px; font-weight:700; color:#d4a84b; }
        QLabel#kpiValueAlert[alert="true"] { font-size:28px; font-weight:700; color:#ff9b9b; }
        QLabel#kpiValueAlert[alert="false"] { font-size:28px; font-weight:700; color:#d4e8d0; }
        QLabel#wsBadgeIcon {
            background-color:#1e3d1e; color:#d4e8d0; border-radius:19px;
            font-weight:700; font-size:15px;
        }
        QLabel#wsBadgeTitle { font-weight:700; font-size:14px; color:#d4e8d0; background:transparent; }
        QLabel#wsBadgeSubtitle { font-size:12px; color:#8ab88a; background:transparent; }
        QFrame#wsBadgeRow { background:transparent; border:none; }
        QLineEdit#readonlyDbPath {
            background-color:#1e3d1e; color:#d4e8d0; border:1px solid #2e6b2e;
            border-radius:6px; padding:8px 12px;
            font-family:'JetBrains Mono','Consolas',monospace; font-size:13px;
        }
        QLabel#mutedNote { font-size:12px; color:#8ab88a; }
        QFrame#dangerZone {
            background-color:rgba(255,155,155,0.08); border:1px solid rgba(255,155,155,0.35);
            border-radius:10px;
        }
        QLabel#dangerTitle { font-size:13px; font-weight:600; color:#ff9b9b; background:transparent; }
        QLabel#dangerDesc { font-size:12px; color:#8ab88a; background:transparent; }
    """,
}


# ─────────────────────────────────────────────────────────────────────
#  CONFIRMATION DIALOG
# ─────────────────────────────────────────────────────────────────────
class ConfirmDialog(QtWidgets.QDialog, Ui_Dialog):
    def __init__(self, message=None, parent=None):
        super().__init__(parent)
        self.setupUi(self)
        if message:
            self.label.setText(message)
        if parent:
            geo = parent.geometry()
            x = geo.x() + (geo.width()  - self.width())  // 2
            y = geo.y() + (geo.height() - self.height()) // 2
            self.move(x, y)


# ─────────────────────────────────────────────────────────────────────
#  MAIN APPLICATION
# ─────────────────────────────────────────────────────────────────────
class SmartStockApp(QtWidgets.QMainWindow, Ui_MainWindow):
    def __init__(self, is_sandbox=False):
        super().__init__()
        self.setupUi(self)

        if is_sandbox:
            self.db_name = "smartstock_sandbox.db"
            self.setWindowTitle(
                "SmartStock Inventory System (SANDBOX / DEVELOPMENT ENVIRONMENT)"
            )
        else:
            self.db_name = "smartstock.db"
            self.setWindowTitle("SmartStock Inventory System")

        self._current_page = 0
        self._records_per_page = 50
        self._search_filter = ""
        self._total_records = 0
        self._analytics_canvas = None
        self._current_theme = "Default"
        # Audit log pagination / filter state
        self._audit_page = 0
        self._audit_total = 0
        self._audit_records_per_page = 100
        os.makedirs(BARCODE_DIR, exist_ok=True)
        self.init_database()

        self.stackedWidget.setCurrentWidget(self.page_dashboard)
        self.txt_db_path.setText(os.path.abspath(self.db_name))

        self.combo_theme.blockSignals(True)
        self.combo_theme.clear()
        for name in THEMES:
            self.combo_theme.addItem(name)
        self.combo_theme.setCurrentIndex(0)
        self.combo_theme.blockSignals(False)

        self.load_categories()
        self.load_table_data()
        self.load_category_list()
        self._update_kpi_cards()

        # Navigation
        self.btn_nav_dashboard.clicked.connect(self._go_dashboard)
        self.btn_nav_reports.clicked.connect(self._go_reports)
        self.btn_nav_audit.clicked.connect(self._go_audit)
        self.btn_nav_settings.clicked.connect(self._go_settings)

        # Dashboard
        self.btn_add_7.clicked.connect(self.add_item)
        self.btn_clear_7.clicked.connect(self.clear_form)
        self.btn_update.clicked.connect(self.update_item)
        self.btn_delete_item.clicked.connect(self.delete_item)
        self.btn_restock.clicked.connect(self.restock_item)
        self.btn_dispense.clicked.connect(self.dispense_item)
        self.btn_view_history.clicked.connect(self.open_item_history)
        self.tableInventory.itemClicked.connect(self.map_data_to_inputs)
        self.tableInventory.itemSelectionChanged.connect(self._on_inventory_selection_changed)
        self.search_input.textChanged.connect(self.handle_live_search)
        self.btn_page_prev.clicked.connect(self._go_page_prev)
        self.btn_page_next.clicked.connect(self._go_page_next)

        # Reports
        self.btn_import.clicked.connect(self.import_csv_data)
        self.btn_export.clicked.connect(self.export_to_csv)
        self.btn_export_pdf.clicked.connect(self.export_pdf_report)

        # Audit log
        self.btn_audit_filter.clicked.connect(self._audit_apply_filters)
        self.btn_audit_clear.clicked.connect(self._audit_clear_filters)
        self.btn_audit_prev.clicked.connect(self._audit_go_prev)
        self.btn_audit_next.clicked.connect(self._audit_go_next)
        self.btn_audit_export.clicked.connect(self.export_audit_csv)

        # Settings
        self.btn_backup.clicked.connect(self.handle_backup)
        self.btn_reset_all.clicked.connect(self.handle_system_reset)
        self.chk_dark_mode.stateChanged.connect(self.toggle_dark_mode)
        self.combo_theme.currentTextChanged.connect(self.apply_theme)
        self.btn_add_category.clicked.connect(self.add_custom_category)
        self.btn_remove_category.clicked.connect(self.remove_category)

        self.apply_theme(self.combo_theme.currentText())
        self.statusBar().showMessage("SmartStock Inventory System ready.")

    # ── Nav ───────────────────────────────────────────────────────────
    def _set_nav_active(self, active_btn):
        for btn in (self.btn_nav_dashboard, self.btn_nav_reports,
                    self.btn_nav_audit, self.btn_nav_settings):
            btn.setObjectName("navBtnActive" if btn is active_btn else "navBtn")
            btn.style().unpolish(btn)
            btn.style().polish(btn)

    def _go_dashboard(self):
        self._set_nav_active(self.btn_nav_dashboard)
        self.stackedWidget.setCurrentWidget(self.page_dashboard)

    def _go_reports(self):
        self._set_nav_active(self.btn_nav_reports)
        self.stackedWidget.setCurrentWidget(self.page_reports)
        self.refresh_report_data()
        self.render_analytics_graphs()

    def _go_audit(self):
        self._set_nav_active(self.btn_nav_audit)
        self.stackedWidget.setCurrentWidget(self.page_audit)
        self._audit_populate_item_combo()
        self._audit_page = 0
        self.load_audit_data()

    def _go_settings(self):
        self._set_nav_active(self.btn_nav_settings)
        self.stackedWidget.setCurrentWidget(self.page_settings)
        self.load_category_list()

    # ── Database ──────────────────────────────────────────────────────
    def init_database(self):
        with sqlite3.connect(self.db_name) as conn:
            conn.execute("PRAGMA foreign_keys = ON;")
            c = conn.cursor()
            c.execute("""CREATE TABLE IF NOT EXISTS Category (
                            CategoryID   INTEGER PRIMARY KEY AUTOINCREMENT,
                            CategoryName TEXT UNIQUE)""")
            c.execute("""CREATE TABLE IF NOT EXISTS Item (
                            ItemID       INTEGER PRIMARY KEY AUTOINCREMENT,
                            ItemName     TEXT,
                            SKU          TEXT,
                            Quantity     INTEGER,
                            UnitPrice    REAL,
                            CategoryID   INTEGER,
                            ReorderLevel INTEGER NOT NULL DEFAULT 5,
                            FOREIGN KEY (CategoryID) REFERENCES Category(CategoryID))""")
            c.execute("""CREATE TABLE IF NOT EXISTS InventoryLedger (
                            LedgerID          INTEGER PRIMARY KEY AUTOINCREMENT,
                            ItemID            INTEGER,
                            ItemNameSnapshot  TEXT,
                            DeltaQuantity     INTEGER,
                            PriceSnapshot     REAL,
                            ChangeType        TEXT,
                            Timestamp         DATETIME DEFAULT CURRENT_TIMESTAMP,
                            FOREIGN KEY (ItemID) REFERENCES Item(ItemID) ON DELETE SET NULL)""")
            # ── Ledger migration guard (existing databases) ───────────
            c.execute("PRAGMA table_info(InventoryLedger)")
            ledger_cols = [row[1] for row in c.fetchall()]
            if "ItemNameSnapshot" not in ledger_cols:
                c.execute(
                    "ALTER TABLE InventoryLedger ADD COLUMN ItemNameSnapshot TEXT"
                )
            c.execute("PRAGMA table_info(Item)")
            cols = [row[1] for row in c.fetchall()]
            if "ReorderLevel" not in cols:
                c.execute(
                    "ALTER TABLE Item ADD COLUMN ReorderLevel INTEGER NOT NULL DEFAULT 5"
                )
            if "SKU" not in cols:
                c.execute("ALTER TABLE Item ADD COLUMN SKU TEXT")
            c.execute("SELECT COUNT(*) FROM Category")
            if c.fetchone()[0] == 0:
                c.executemany(
                    "INSERT INTO Category (CategoryName) VALUES (?)",
                    [("Electronics",), ("Stationery",), ("Groceries",), ("Hardware",)],
                )

    # Valid change-type tags — validated at write time (defensive programming).
    _VALID_CHANGE_TYPES = frozenset({"CREATE", "MANUAL_EDIT", "CSV_IMPORT", "RESTOCK", "DISPENSE"})

    def _write_ledger(self, cursor, item_id, delta_qty, price_snapshot, change_type,
                      item_name_snapshot=""):
        """
        Write one immutable audit entry within the caller's active transaction.

        Uses cursor injection (Choice A) so the ledger write and the inventory
        change are always committed atomically — neither can succeed without
        the other.

        Raises ValueError for unknown change_type tags so future callers get
        an immediate, descriptive error rather than silent data corruption.
        """
        if change_type not in self._VALID_CHANGE_TYPES:
            raise ValueError(
                f"_write_ledger: unknown ChangeType '{change_type}'. "
                f"Valid tags: {sorted(self._VALID_CHANGE_TYPES)}"
            )
        cursor.execute(
            "INSERT INTO InventoryLedger "
            "(ItemID, ItemNameSnapshot, DeltaQuantity, PriceSnapshot, ChangeType) "
            "VALUES (?,?,?,?,?)",
            (item_id, item_name_snapshot, delta_qty, price_snapshot, change_type),
        )

    def _generate_sku(self):
        return f"SS-{datetime.now().strftime('%Y%m%d')}-{uuid.uuid4().hex[:8].upper()}"

    def _save_barcode_image(self, sku):
        path = os.path.join(BARCODE_DIR, f"{sku}.png")
        if HAS_BARCODE:
            try:
                Code128(sku, writer=ImageWriter()).save(
                    os.path.join(BARCODE_DIR, sku)
                )
                return os.path.join(BARCODE_DIR, f"{sku}.png")
            except Exception:
                pass
        return None

    def _show_barcode_preview(self, image_path, sku=""):
        if image_path and os.path.isfile(image_path):
            pix = QtGui.QPixmap(image_path)
            if not pix.isNull():
                self.lbl_barcode_preview.setPixmap(
                    pix.scaled(
                        280, 100,
                        QtCore.Qt.KeepAspectRatio,
                        QtCore.Qt.SmoothTransformation,
                    )
                )
                self.lbl_barcode_preview.setText("")
                return
        self.lbl_barcode_preview.setPixmap(QtGui.QPixmap())
        self.lbl_barcode_preview.setText(
            f"SKU: {sku}\n(Barcode image unavailable)" if sku else
            "Select an item to preview SKU barcode"
        )

    def _inventory_from_clause(self):
        return (
            " FROM Item JOIN Category ON Item.CategoryID = Category.CategoryID"
        )

    def _inventory_search_clause(self):
        if self._search_filter:
            return (
                " WHERE (Item.ItemName LIKE ? OR Category.CategoryName LIKE ? "
                "OR Item.SKU LIKE ?)",
                [f"%{self._search_filter}%"] * 3,
            )
        return "", []

    # ── Dashboard helpers ─────────────────────────────────────────────
    def load_categories(self):
        self.combo_category_7.clear()
        with sqlite3.connect(self.db_name) as conn:
            conn.execute("PRAGMA foreign_keys = ON;")
            c = conn.cursor()
            c.execute("SELECT CategoryName FROM Category ORDER BY CategoryName")
            for row in c.fetchall():
                self.combo_category_7.addItem(row[0])

    def _populate_inventory_table(self, rows):
        self.tableInventory.setRowCount(0)
        low_color = QtGui.QColor(COLOR["error"])
        for idx, row in enumerate(rows):
            item_id, sku, name, category, qty, price, reorder_level = row
            sku = sku or ""
            reorder_level = int(reorder_level)
            self.tableInventory.insertRow(idx)
            display = [
                f"#INV-{int(item_id):05d}",
                sku,
                name,
                category,
                str(qty),
                f"₱ {float(price):,.2f}",
            ]
            for col, text in enumerate(display):
                cell = QtWidgets.QTableWidgetItem(text)
                if col in (0, 4, 5):
                    cell.setTextAlignment(QtCore.Qt.AlignRight | QtCore.Qt.AlignVCenter)
                if col == 1:
                    barcode_path = os.path.join(BARCODE_DIR, f"{sku}.png") if sku else ""
                    cell.setData(QtCore.Qt.UserRole, barcode_path)
                if col == 4:
                    cell.setData(QtCore.Qt.UserRole, reorder_level)
                    if int(qty) < reorder_level:
                        cell.setForeground(low_color)
                        f = cell.font()
                        f.setBold(True)
                        cell.setFont(f)
                self.tableInventory.setItem(idx, col, cell)
        self.tableInventory.resizeColumnsToContents()
        self.tableInventory.horizontalHeader().setSectionResizeMode(
            2, QtWidgets.QHeaderView.Stretch
        )

    def _update_pagination_controls(self):
        total_pages = max(1, (self._total_records + self._records_per_page - 1)
                          // self._records_per_page)
        if self._current_page >= total_pages:
            self._current_page = max(0, total_pages - 1)
        self.lbl_page_info.setText(
            f"Page {self._current_page + 1} of {total_pages} "
            f"({self._total_records:,} items)"
        )
        self.btn_page_prev.setEnabled(self._current_page > 0)
        self.btn_page_next.setEnabled(
            (self._current_page + 1) * self._records_per_page < self._total_records
        )

    def load_table_data(self):
        where_sql, where_params = self._inventory_search_clause()
        offset = self._current_page * self._records_per_page
        with sqlite3.connect(self.db_name) as conn:
            conn.execute("PRAGMA foreign_keys = ON;")
            c = conn.cursor()
            c.execute(
                "SELECT COUNT(*)" + self._inventory_from_clause() + where_sql,
                where_params,
            )
            self._total_records = c.fetchone()[0]
            c.execute(
                "SELECT Item.ItemID, Item.SKU, Item.ItemName, Category.CategoryName,"
                " Item.Quantity, Item.UnitPrice, Item.ReorderLevel"
                + self._inventory_from_clause()
                + where_sql
                + " ORDER BY Item.ItemID LIMIT ? OFFSET ?",
                where_params + [self._records_per_page, offset],
            )
            rows = c.fetchall()
        self._populate_inventory_table(rows)
        self._update_pagination_controls()

    def handle_live_search(self, text):
        self._search_filter = text.strip()
        self._current_page = 0
        self.load_table_data()

    def _go_page_prev(self):
        if self._current_page > 0:
            self._current_page -= 1
            self.load_table_data()

    def _go_page_next(self):
        if (self._current_page + 1) * self._records_per_page < self._total_records:
            self._current_page += 1
            self.load_table_data()

    def map_data_to_inputs(self):
        row = self.tableInventory.currentRow()
        if row < 0:
            return
        self.input_name_7.setText(self.tableInventory.item(row, 2).text())
        self.combo_category_7.setCurrentText(self.tableInventory.item(row, 3).text())
        self.input_qty_7.setValue(
            int(self.tableInventory.item(row, 4).text().replace(",", ""))
        )
        price = (
            self.tableInventory.item(row, 5)
            .text()
            .replace("₱", "")
            .replace(",", "")
            .strip()
        )
        self.input_price_7.setValue(float(price))
        qty_cell = self.tableInventory.item(row, 4)
        reorder = qty_cell.data(QtCore.Qt.UserRole)
        self.input_reorder_7.setValue(int(reorder) if reorder is not None else 5)
        sku_cell = self.tableInventory.item(row, 1)
        sku_text = sku_cell.text()
        barcode_path = sku_cell.data(QtCore.Qt.UserRole) or ""
        self._show_barcode_preview(barcode_path, sku_text)
        self.statusBar().showMessage(
            f"Row {row + 1} loaded — edit fields then click Update, or Delete to remove.",
            4000,
        )

    # ── CRUD ──────────────────────────────────────────────────────────
    def add_item(self):
        name = self.input_name_7.text().strip()
        if not name:
            QtWidgets.QMessageBox.warning(self, "Validation", "Item name cannot be empty!")
            self.input_name_7.setFocus()
            return
        qty = self.input_qty_7.value()
        price = self.input_price_7.value()
        sku = self._generate_sku()
        self._save_barcode_image(sku)
        try:
            with sqlite3.connect(self.db_name) as conn:
                conn.execute("PRAGMA foreign_keys = ON;")
                c = conn.cursor()
                c.execute(
                    "SELECT CategoryID FROM Category WHERE CategoryName=?",
                    (self.combo_category_7.currentText(),),
                )
                res = c.fetchone()
                if not res:
                    conn.rollback()
                    QtWidgets.QMessageBox.warning(self, "Error", "Category not found.")
                    return
                c.execute(
                    "INSERT INTO Item (ItemName,SKU,Quantity,UnitPrice,CategoryID,ReorderLevel) "
                    "VALUES (?,?,?,?,?,?)",
                    (name, sku, qty, price, res[0], self.input_reorder_7.value()),
                )
                item_id = c.lastrowid
                self._write_ledger(c, item_id, qty, price, "CREATE", name)
        except sqlite3.Error as e:
            QtWidgets.QMessageBox.critical(self, "Database Error", str(e))
            return
        self.load_table_data()
        self._update_kpi_cards()
        self.clear_form()
        self.statusBar().showMessage(f"  '{name}' added to inventory.", 4000)

    def update_item(self):
        row = self.tableInventory.currentRow()
        if row < 0:
            QtWidgets.QMessageBox.information(self, "No Selection", "Click a row first.")
            return
        item_id = int(self.tableInventory.item(row, 0).text().replace("#INV-", ""))
        name = self.input_name_7.text().strip()
        if not name:
            QtWidgets.QMessageBox.warning(self, "Validation", "Item name cannot be empty!")
            return
        new_qty = self.input_qty_7.value()
        new_price = self.input_price_7.value()
        try:
            with sqlite3.connect(self.db_name) as conn:
                conn.execute("PRAGMA foreign_keys = ON;")
                c = conn.cursor()
                c.execute(
                    "SELECT Quantity, UnitPrice FROM Item WHERE ItemID=?", (item_id,)
                )
                old = c.fetchone()
                if not old:
                    conn.rollback()
                    QtWidgets.QMessageBox.warning(self, "Error", "Item not found.")
                    return
                old_qty, old_price = old
                delta_qty = new_qty - int(old_qty)
                c.execute(
                    "SELECT CategoryID FROM Category WHERE CategoryName=?",
                    (self.combo_category_7.currentText(),),
                )
                res = c.fetchone()
                if not res:
                    conn.rollback()
                    QtWidgets.QMessageBox.warning(self, "Error", "Category not found.")
                    return
                c.execute(
                    "UPDATE Item SET ItemName=?,Quantity=?,UnitPrice=?,CategoryID=?,"
                    "ReorderLevel=? WHERE ItemID=?",
                    (
                        name, new_qty, new_price, res[0],
                        self.input_reorder_7.value(), item_id,
                    ),
                )
                if delta_qty != 0 or new_price != old_price:
                    self._write_ledger(
                        c, item_id, delta_qty, new_price, "MANUAL_EDIT", name
                    )
        except sqlite3.Error as e:
            QtWidgets.QMessageBox.critical(self, "Database Error", str(e))
            return
        self.load_table_data()
        self._update_kpi_cards()
        self.clear_form()
        self.statusBar().showMessage(f"  Item #{item_id:05d} updated.", 4000)

    def delete_item(self):
        row = self.tableInventory.currentRow()
        if row < 0:
            QtWidgets.QMessageBox.information(self, "No Selection", "Click a row first.")
            return
        item_id = int(self.tableInventory.item(row, 0).text().replace("#INV-", ""))
        item_name = self.tableInventory.item(row, 2).text()
        dlg = ConfirmDialog(
            f"Delete '{item_name}' (#{item_id:05d})?\n\nThis cannot be undone.", parent=self
        )
        if dlg.exec_() == QtWidgets.QDialog.Accepted:
            with sqlite3.connect(self.db_name) as conn:
                conn.execute("PRAGMA foreign_keys = ON;")
                conn.cursor().execute("DELETE FROM Item WHERE ItemID=?", (item_id,))
            self.load_table_data()
            self._update_kpi_cards()
            self.clear_form()
            self.statusBar().showMessage(f"  '{item_name}' deleted.", 4000)

    def restock_item(self):
        self._adjust_stock(+1)

    def dispense_item(self):
        self._adjust_stock(-1)

    def _adjust_stock(self, direction):
        row = self.tableInventory.currentRow()
        if row < 0:
            QtWidgets.QMessageBox.information(self, "No Selection", "Click a row first.")
            return
        item_id = int(self.tableInventory.item(row, 0).text().replace("#INV-", ""))
        item_name = self.tableInventory.item(row, 2).text()
        current_qty = int(self.tableInventory.item(row, 4).text().replace(",", ""))
        if direction > 0:
            title, label = "Restock Item", "Restock quantity:"
        else:
            title, label = "Dispense Item", "Dispense quantity:"
        amount, ok = QtWidgets.QInputDialog.getInt(self, title, label, 1, 1, 999999)
        if not ok:
            return
        delta = amount if direction > 0 else -amount
        if current_qty + delta < 0:
            QtWidgets.QMessageBox.warning(
                self,
                "Insufficient Stock",
                f"Cannot dispense {amount} — only {current_qty} in stock.",
            )
            return
        change_type = "RESTOCK" if direction > 0 else "DISPENSE"
        try:
            with sqlite3.connect(self.db_name) as conn:
                conn.execute("PRAGMA foreign_keys = ON;")
                c = conn.cursor()
                c.execute("SELECT UnitPrice FROM Item WHERE ItemID=?", (item_id,))
                row_price = c.fetchone()
                if not row_price:
                    conn.rollback()
                    QtWidgets.QMessageBox.warning(self, "Error", "Item not found.")
                    return
                price = row_price[0]
                c.execute(
                    "UPDATE Item SET Quantity = Quantity + ? WHERE ItemID=?",
                    (delta, item_id),
                )
                self._write_ledger(c, item_id, delta, price, change_type, item_name)
        except sqlite3.Error as e:
            QtWidgets.QMessageBox.critical(self, "Database Error", str(e))
            return
        self.load_table_data()
        self._update_kpi_cards()
        verb = "Restocked" if direction > 0 else "Dispensed"
        self.statusBar().showMessage(f"  {verb} {amount} unit(s) for '{item_name}'.", 4000)

    def _on_inventory_selection_changed(self):
        """Enable/disable the View History button based on whether a row is selected."""
        has_selection = self.tableInventory.currentRow() >= 0
        self.btn_view_history.setEnabled(has_selection)

    def open_item_history(self):
        """Open the per-item drill-down modal (Option B)."""
        row = self.tableInventory.currentRow()
        if row < 0:
            return
        item_id   = int(self.tableInventory.item(row, 0).text().replace("#INV-", ""))
        item_name = self.tableInventory.item(row, 2).text()
        sku       = self.tableInventory.item(row, 1).text()
        dlg = ItemHistoryDialog(item_id, item_name, sku, self.db_name, parent=self)
        # Wire the export button inside the dialog
        dlg.btn_export_item.clicked.connect(
            lambda: self._export_item_history_csv(item_id, item_name)
        )
        dlg.exec_()

    def _export_item_history_csv(self, item_id, item_name):
        safe_name = "".join(c for c in item_name if c.isalnum() or c in " _-")[:40].strip()
        path, _ = QtWidgets.QFileDialog.getSaveFileName(
            self,
            "Export Item History",
            f"history_{safe_name}.csv",
            "CSV Files (*.csv)",
        )
        if not path:
            return
        with sqlite3.connect(self.db_name) as conn:
            c = conn.cursor()
            c.execute(
                "SELECT Timestamp, ChangeType, DeltaQuantity, PriceSnapshot, "
                "SUM(DeltaQuantity) OVER ("
                "  PARTITION BY ItemID ORDER BY LedgerID "
                "  ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW"
                ") AS RunningBalance "
                "FROM InventoryLedger WHERE ItemID=? ORDER BY LedgerID",
                (item_id,),
            )
            rows = c.fetchall()
        with open(path, "w", newline="", encoding="utf-8") as f:
            w = csv.writer(f)
            w.writerow(["Timestamp", "ChangeType", "DeltaQuantity", "PriceSnapshot", "RunningBalance"])
            w.writerows(rows)
        QtWidgets.QMessageBox.information(self, "Export Successful", f"Saved to:\n{path}")

    def clear_form(self):
        self.input_name_7.clear()
        self.input_qty_7.setValue(0)
        self.input_price_7.setValue(0.0)
        self.input_reorder_7.setValue(5)
        self.tableInventory.clearSelection()
        self._show_barcode_preview(None)
        self.input_name_7.setFocus()
        self.statusBar().showMessage("Form cleared.", 2000)

    # ── Reports ───────────────────────────────────────────────────────
    def _update_kpi_cards(self):
        with sqlite3.connect(self.db_name) as conn:
            conn.execute("PRAGMA foreign_keys = ON;")
            c = conn.cursor()
            c.execute("SELECT SUM(Quantity), SUM(Quantity*UnitPrice) FROM Item")
            qty, val = c.fetchone()
            c.execute("SELECT COUNT(*) FROM Item WHERE Quantity < ReorderLevel")
            low = c.fetchone()[0]
        self.lbl_total_items.setText(f"{qty or 0:,}")
        self.lbl_total_value.setText(f"₱{val or 0:,.0f}")
        self.lbl_low_stock.setText(str(low))
        self.lbl_low_stock.setProperty("alert", "true" if low > 0 else "false")
        self.lbl_low_stock.style().unpolish(self.lbl_low_stock)
        self.lbl_low_stock.style().polish(self.lbl_low_stock)

    def refresh_report_data(self):
        self._update_kpi_cards()
        with sqlite3.connect(self.db_name) as conn:
            conn.execute("PRAGMA foreign_keys = ON;")
            c = conn.cursor()
            c.execute("""SELECT Category.CategoryName, SUM(Item.Quantity)
                         FROM Item JOIN Category ON Item.CategoryID=Category.CategoryID
                         GROUP BY Category.CategoryName""")
            self.table_reports.setRowCount(0)
            for idx, row in enumerate(c.fetchall()):
                self.table_reports.insertRow(idx)
                self.table_reports.setItem(
                    idx, 0, QtWidgets.QTableWidgetItem(str(row[0]))
                )
                cell = QtWidgets.QTableWidgetItem(f"{row[1]:,}")
                cell.setTextAlignment(QtCore.Qt.AlignRight | QtCore.Qt.AlignVCenter)
                self.table_reports.setItem(idx, 1, cell)
            self.table_reports.resizeColumnsToContents()

    def _chart_colors(self):
        return THEME_CHART_COLORS.get(self._current_theme, THEME_CHART_COLORS["Default"])

    def _style_chart_axes(self, axes, colors):
        for ax in axes:
            ax.set_facecolor(colors["surface"])
            ax.tick_params(colors=colors["on_surface"], labelsize=10)
            for spine in ax.spines.values():
                spine.set_color(colors["outline"])
            ax.title.set_color(colors["primary"])
            ax.xaxis.label.set_color(colors["on_surface"])
            ax.yaxis.label.set_color(colors["on_surface"])

    def render_analytics_graphs(self):
        if not HAS_MPL:
            return
        while self.analytics_charts_layout.count():
            child = self.analytics_charts_layout.takeAt(0)
            if child.widget():
                child.widget().deleteLater()
        colors = self._chart_colors()
        fig = Figure(figsize=(7.2, 2.8), dpi=110)
        fig.patch.set_facecolor(colors["background"])
        ax_pie = fig.add_subplot(121)
        ax_bar = fig.add_subplot(122)
        with sqlite3.connect(self.db_name) as conn:
            conn.execute("PRAGMA foreign_keys = ON;")
            c = conn.cursor()
            c.execute(
                "SELECT Category.CategoryName, SUM(Item.Quantity * Item.UnitPrice) "
                "FROM Item JOIN Category ON Item.CategoryID = Category.CategoryID "
                "GROUP BY Category.CategoryID"
            )
            cat_rows = c.fetchall()
            c.execute(
                "SELECT Item.ItemName, Item.Quantity, Item.ReorderLevel "
                "FROM Item ORDER BY "
                "CAST(Item.Quantity AS REAL) / MAX(Item.ReorderLevel, 1) ASC "
                "LIMIT 5"
            )
            low_rows = c.fetchall()
        pie_palette = colors["palette"]
        if cat_rows:
            labels, values = zip(*cat_rows)
            ax_pie.pie(
                values,
                labels=labels,
                autopct="%1.0f%%",
                colors=pie_palette[: len(labels)],
                textprops={"color": colors["on_surface"], "fontsize": 10},
                wedgeprops={"edgecolor": colors["outline"], "linewidth": 0.6},
            )
            ax_pie.set_title(
                "Asset Value by Category",
                color=colors["primary"],
                fontsize=12,
                fontweight="bold",
            )
        else:
            ax_pie.text(
                0.5, 0.5, "No data", ha="center", va="center",
                color=colors["on_surface"], fontsize=11,
            )
            ax_pie.set_title(
                "Asset Value by Category",
                color=colors["primary"],
                fontsize=12,
                fontweight="bold",
            )
        if low_rows:
            names = [r[0][:18] for r in low_rows]
            ratios = [int(r[1]) / max(int(r[2]), 1) for r in low_rows]
            y_pos = range(len(names))
            ax_bar.barh(y_pos, ratios, color=colors["error"], alpha=0.88)
            ax_bar.set_yticks(y_pos)
            ax_bar.set_yticklabels(names, color=colors["on_surface"], fontsize=10)
            ax_bar.set_xlabel("Qty / Reorder Ratio", color=colors["on_surface"], fontsize=10)
            ax_bar.set_title(
                "Low Stock Threats (Top 5)",
                color=colors["error"],
                fontsize=12,
                fontweight="bold",
            )
        else:
            ax_bar.text(
                0.5, 0.5, "No data", ha="center", va="center",
                color=colors["on_surface"], fontsize=11,
            )
            ax_bar.set_title(
                "Low Stock Threats (Top 5)",
                color=colors["error"],
                fontsize=12,
                fontweight="bold",
            )
        self._style_chart_axes((ax_pie, ax_bar), colors)
        fig.subplots_adjust(left=0.08, right=0.98, top=0.86, bottom=0.20, wspace=0.38)
        canvas = FigureCanvas(fig)
        canvas.setSizePolicy(
            QtWidgets.QSizePolicy.Expanding, QtWidgets.QSizePolicy.Fixed
        )
        canvas.setFixedHeight(248)
        self.analytics_charts_layout.addWidget(canvas)
        self._analytics_canvas = canvas

    def export_pdf_report(self):
        if not HAS_REPORTLAB:
            QtWidgets.QMessageBox.warning(
                self,
                "Missing Dependency",
                "Install reportlab to export PDF reports:\npip install reportlab",
            )
            return
        path, _ = QtWidgets.QFileDialog.getSaveFileName(
            self, "Export PDF Report", "smartstock_report.pdf", "PDF Files (*.pdf)"
        )
        if not path:
            return
        if not path.lower().endswith(".pdf"):
            path += ".pdf"
        try:
            with sqlite3.connect(self.db_name) as conn:
                conn.execute("PRAGMA foreign_keys = ON;")
                c = conn.cursor()
                c.execute(
                    "SELECT Item.ItemID, Item.SKU, Item.ItemName, Category.CategoryName,"
                    " Item.Quantity, Item.UnitPrice, Item.ReorderLevel"
                    + self._inventory_from_clause()
                    + " ORDER BY Item.ItemID"
                )
                rows = c.fetchall()
                c.execute(
                    "SELECT SUM(Quantity), SUM(Quantity * UnitPrice) FROM Item"
                )
                total_qty, total_val = c.fetchone()
            doc = SimpleDocTemplate(path, pagesize=letter)
            styles = getSampleStyleSheet()
            title_style = ParagraphStyle(
                "CorpTitle",
                parent=styles["Heading1"],
                textColor=rl_colors.HexColor(COLOR["primary"]),
                fontSize=20,
                spaceAfter=6,
            )
            story = [
                Paragraph("SmartStock Inventory — Corporate Report", title_style),
                Paragraph(
                    f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
                    styles["Normal"],
                ),
                Spacer(1, 0.25 * inch),
            ]
            table_data = [
                ["ID", "SKU", "Item", "Category", "Qty", "Unit Price", "Value"]
            ]
            for r in rows:
                item_id, sku, name, cat, qty, price, _ = r
                sku = sku or ""
                table_data.append([
                    f"#{int(item_id):05d}",
                    sku,
                    name,
                    cat,
                    str(qty),
                    f"₱{float(price):,.2f}",
                    f"₱{qty * float(price):,.2f}",
                ])
            table_data.append([
                "", "", "", "TOTALS",
                f"{int(total_qty or 0):,}",
                "",
                f"₱{float(total_val or 0):,.2f}",
            ])
            tbl = Table(table_data, repeatRows=1)
            tbl.setStyle(TableStyle([
                ("BACKGROUND", (0, 0), (-1, 0), rl_colors.HexColor(COLOR["primary_container"])),
                ("TEXTCOLOR", (0, 0), (-1, 0), rl_colors.HexColor(COLOR["on_primary_container"])),
                ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
                ("FONTSIZE", (0, 0), (-1, -1), 8),
                ("ALIGN", (4, 1), (-1, -1), "RIGHT"),
                ("GRID", (0, 0), (-1, -2), 0.5, rl_colors.HexColor(COLOR["outline_variant"])),
                ("ROWBACKGROUNDS", (0, 1), (-1, -2), [
                    rl_colors.HexColor(COLOR["surface_container_lowest"]),
                    rl_colors.HexColor(COLOR["surface_container_low"]),
                ]),
                ("BACKGROUND", (0, -1), (-1, -1), rl_colors.HexColor(COLOR["secondary_container"])),
                ("FONTNAME", (0, -1), (-1, -1), "Helvetica-Bold"),
                ("SPAN", (0, -1), (3, -1)),
            ]))
            story.append(tbl)
            doc.build(story)
            QtWidgets.QMessageBox.information(
                self, "Export Successful", f"PDF report saved to:\n{path}"
            )
            self.statusBar().showMessage(f"PDF exported to {path}", 5000)
        except Exception as e:
            QtWidgets.QMessageBox.critical(self, "PDF Export Failed", str(e))

    def _sanitize_csv_item_name(self, name):
        name = name.strip()
        if name and name[0] in ("=", "+", "-", "@"):
            name = "'" + name
        return name

    def import_csv_data(self):
        path, _ = QtWidgets.QFileDialog.getOpenFileName(
            self, "Import Inventory CSV", "", "CSV Files (*.csv)"
        )
        if not path:
            return

        required = {"ItemName", "Category", "Quantity", "UnitPrice"}
        try:
            with open(path, newline="", encoding="utf-8-sig") as f:
                reader = csv.DictReader(f)
                if not reader.fieldnames:
                    QtWidgets.QMessageBox.critical(
                        self, "Import Failed", "CSV file is empty or has no headers."
                    )
                    return
                if not required.issubset(set(reader.fieldnames)):
                    missing = required - set(reader.fieldnames)
                    QtWidgets.QMessageBox.critical(
                        self,
                        "Import Failed",
                        f"Missing required column(s): {', '.join(sorted(missing))}\n\n"
                        "Required headers: ItemName, Category, Quantity, UnitPrice",
                    )
                    return
                rows = list(reader)
        except OSError as e:
            QtWidgets.QMessageBox.critical(self, "Import Failed", f"Could not read file:\n{e}")
            return

        try:
            with sqlite3.connect(self.db_name) as conn:
                conn.execute("PRAGMA foreign_keys = ON;")
                c = conn.cursor()
                count = 0

                # ── Duplicate-name pre-flight check ───────────────────
                incoming_names = [
                    self._sanitize_csv_item_name(r.get("ItemName", ""))
                    for r in rows
                ]
                placeholders = ",".join("?" * len(incoming_names))
                c.execute(
                    f"SELECT ItemName FROM Item WHERE ItemName IN ({placeholders})",
                    incoming_names,
                )
                duplicates = [r[0] for r in c.fetchall()]
                if duplicates:
                    sample = ", ".join(f"'{n}'" for n in duplicates[:5])
                    more   = f" … and {len(duplicates) - 5} more" if len(duplicates) > 5 else ""
                    reply  = QtWidgets.QMessageBox.warning(
                        self,
                        "Duplicate Item Names Detected",
                        f"The following item name(s) already exist in the database:\n\n"
                        f"{sample}{more}\n\n"
                        f"Proceeding will create additional entries with the same name.\n"
                        f"Continue anyway?",
                        QtWidgets.QMessageBox.Yes | QtWidgets.QMessageBox.Cancel,
                        QtWidgets.QMessageBox.Cancel,
                    )
                    if reply != QtWidgets.QMessageBox.Yes:
                        return
                for row_num, row in enumerate(rows, start=2):
                    name = self._sanitize_csv_item_name(row.get("ItemName", ""))
                    category = row.get("Category", "").strip()
                    qty_str = row.get("Quantity", "").strip()
                    price_str = row.get("UnitPrice", "").strip()

                    if not name:
                        raise ValueError(f"Row {row_num}: ItemName is blank.")
                    if not category:
                        raise ValueError(f"Row {row_num}: Category is blank.")
                    if not qty_str:
                        raise ValueError(f"Row {row_num}: Quantity is blank.")
                    if not price_str:
                        raise ValueError(f"Row {row_num}: UnitPrice is blank.")

                    try:
                        qty = int(qty_str)
                    except ValueError as exc:
                        raise ValueError(
                            f"Row {row_num}: Quantity '{qty_str}' is not a valid integer."
                        ) from exc
                    try:
                        price = float(price_str)
                    except ValueError as exc:
                        raise ValueError(
                            f"Row {row_num}: UnitPrice '{price_str}' is not a valid number."
                        ) from exc

                    c.execute(
                        "SELECT CategoryID FROM Category WHERE CategoryName=?", (category,)
                    )
                    res = c.fetchone()
                    if res:
                        cat_id = res[0]
                    else:
                        c.execute(
                            "INSERT INTO Category (CategoryName) VALUES (?)", (category,)
                        )
                        cat_id = c.lastrowid

                    sku = self._generate_sku()
                    self._save_barcode_image(sku)
                    c.execute(
                        "INSERT INTO Item (ItemName, SKU, Quantity, UnitPrice, CategoryID) "
                        "VALUES (?, ?, ?, ?, ?)",
                        (name, sku, qty, price, cat_id),
                    )
                    item_id = c.lastrowid
                    self._write_ledger(c, item_id, qty, price, "CSV_IMPORT", name)
                    count += 1
        except (ValueError, sqlite3.Error) as e:
            QtWidgets.QMessageBox.critical(self, "Import Failed", str(e))
            return

        self.load_categories()
        self.load_table_data()
        self._update_kpi_cards()
        QtWidgets.QMessageBox.information(
            self, "Import Successful", f"Successfully imported {count} item(s)."
        )
        self.statusBar().showMessage(f"Imported {count} item(s) from CSV.", 5000)

    def export_to_csv(self):
        path, _ = QtWidgets.QFileDialog.getSaveFileName(
            self, "Export Inventory", "inventory_report.csv", "CSV Files (*.csv)"
        )
        if path:
            with sqlite3.connect(self.db_name) as conn:
                conn.execute("PRAGMA foreign_keys = ON;")
                c = conn.cursor()
                c.execute("""SELECT Item.ItemID, Item.SKU, Item.ItemName, Category.CategoryName,
                                    Item.Quantity, Item.UnitPrice
                             FROM Item JOIN Category ON Item.CategoryID=Category.CategoryID""")
                rows = c.fetchall()
            with open(path, "w", newline="", encoding="utf-8") as f:
                w = csv.writer(f)
                w.writerow(["ItemID", "SKU", "ItemName", "Category", "Quantity", "UnitPrice"])
                w.writerows(rows)
            QtWidgets.QMessageBox.information(
                self, "Export Successful", f"Inventory exported to:\n{path}"
            )
            self.statusBar().showMessage(f"Exported to {path}", 5000)

    # ── Audit Log (Global Timeline – Option A) ────────────────────────
    def _audit_populate_item_combo(self):
        """Refresh the item filter combo with current item names from the database."""
        self.audit_combo_item.blockSignals(True)
        current_text = self.audit_combo_item.currentText()
        self.audit_combo_item.clear()
        self.audit_combo_item.addItem("All Items")
        with sqlite3.connect(self.db_name) as conn:
            c = conn.cursor()
            # Include items that appear in the ledger even if since deleted (SET NULL rows
            # won't appear here, but any still-existing item with ledger entries will).
            c.execute(
                "SELECT DISTINCT i.ItemName FROM InventoryLedger il "
                "JOIN Item i ON il.ItemID = i.ItemID ORDER BY i.ItemName"
            )
            for (name,) in c.fetchall():
                self.audit_combo_item.addItem(name)
        idx = self.audit_combo_item.findText(current_text)
        self.audit_combo_item.setCurrentIndex(idx if idx >= 0 else 0)
        self.audit_combo_item.blockSignals(False)

    def _audit_build_where(self):
        """Return (where_sql, params) for the current filter state."""
        clauses, params = [], []

        item_text = self.audit_combo_item.currentText()
        if item_text != "All Items":
            clauses.append("i.ItemName = ?")
            params.append(item_text)

        type_text = self.audit_combo_type.currentText()
        if type_text != "All Types":
            clauses.append("il.ChangeType = ?")
            params.append(type_text)

        date_from = self.audit_date_from.date().toString("yyyy-MM-dd")
        date_to   = self.audit_date_to.date().toString("yyyy-MM-dd")
        clauses.append("DATE(il.Timestamp) BETWEEN ? AND ?")
        params.extend([date_from, date_to])

        where_sql = ("WHERE " + " AND ".join(clauses)) if clauses else ""
        return where_sql, params

    def load_audit_data(self):
        where_sql, params = self._audit_build_where()
        offset = self._audit_page * self._audit_records_per_page

        base_from = (
            " FROM InventoryLedger il "
            "LEFT JOIN Item i ON il.ItemID = i.ItemID "
        )

        with sqlite3.connect(self.db_name) as conn:
            c = conn.cursor()
            c.execute(f"SELECT COUNT(*){base_from}{where_sql}", params)
            self._audit_total = c.fetchone()[0]

            c.execute(
                "SELECT il.Timestamp, "
                "COALESCE(i.ItemName, il.ItemNameSnapshot, '[Deleted Item]'), "
                "COALESCE(i.SKU, '—'), "
                "il.ChangeType, "
                "il.DeltaQuantity, "
                "il.PriceSnapshot, "
                "SUM(il.DeltaQuantity) OVER ("
                "  PARTITION BY il.ItemID ORDER BY il.LedgerID "
                "  ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW"
                ") AS RunningBalance "
                f"{base_from}{where_sql}"
                " ORDER BY il.LedgerID DESC "
                "LIMIT ? OFFSET ?",
                params + [self._audit_records_per_page, offset],
            )
            rows = c.fetchall()

        _populate_ledger_table(self.tableAudit, rows, show_item_cols=True)

        total_pages = max(1, (self._audit_total + self._audit_records_per_page - 1)
                          // self._audit_records_per_page)
        if self._audit_page >= total_pages:
            self._audit_page = max(0, total_pages - 1)
        self.lbl_audit_page_info.setText(
            f"Page {self._audit_page + 1} of {total_pages}  ({self._audit_total:,} entries)"
        )
        self.lbl_audit_meta.setText(
            f"InventoryLedger  ·  {self._audit_total:,} rows matched"
        )
        self.btn_audit_prev.setEnabled(self._audit_page > 0)
        self.btn_audit_next.setEnabled(
            (self._audit_page + 1) * self._audit_records_per_page < self._audit_total
        )

    def _audit_apply_filters(self):
        self._audit_page = 0
        self.load_audit_data()

    def _audit_clear_filters(self):
        self.audit_combo_item.setCurrentIndex(0)
        self.audit_combo_type.setCurrentIndex(0)
        self.audit_date_from.setDate(QtCore.QDate.currentDate().addDays(-30))
        self.audit_date_to.setDate(QtCore.QDate.currentDate())
        self._audit_page = 0
        self.load_audit_data()

    def _audit_go_prev(self):
        if self._audit_page > 0:
            self._audit_page -= 1
            self.load_audit_data()

    def _audit_go_next(self):
        if (self._audit_page + 1) * self._audit_records_per_page < self._audit_total:
            self._audit_page += 1
            self.load_audit_data()

    def export_audit_csv(self):
        path, _ = QtWidgets.QFileDialog.getSaveFileName(
            self, "Export Audit Ledger", "smartstock_audit_ledger.csv", "CSV Files (*.csv)"
        )
        if not path:
            return
        where_sql, params = self._audit_build_where()
        base_from = (
            " FROM InventoryLedger il "
            "LEFT JOIN Item i ON il.ItemID = i.ItemID "
        )
        with sqlite3.connect(self.db_name) as conn:
            c = conn.cursor()
            c.execute(
                "SELECT il.Timestamp, "
                "COALESCE(i.ItemName, il.ItemNameSnapshot, '[Deleted Item]'), "
                "COALESCE(i.SKU, '—'), "
                "il.ChangeType, il.DeltaQuantity, il.PriceSnapshot, "
                "SUM(il.DeltaQuantity) OVER ("
                "  PARTITION BY il.ItemID ORDER BY il.LedgerID "
                "  ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW"
                ") AS RunningBalance "
                f"{base_from}{where_sql}"
                " ORDER BY il.LedgerID",
                params,
            )
            rows = c.fetchall()
        with open(path, "w", newline="", encoding="utf-8") as f:
            w = csv.writer(f)
            w.writerow([
                "Timestamp (UTC)", "Item Name", "SKU", "Change Type",
                "Delta Quantity", "Price Snapshot", "Running Balance",
            ])
            w.writerows(rows)
        QtWidgets.QMessageBox.information(self, "Export Successful", f"Saved to:\n{path}")
        self.statusBar().showMessage(f"Audit ledger exported to {path}", 5000)

    # ── Settings ──────────────────────────────────────────────────────
    def load_category_list(self):
        self.list_categories.clear()
        with sqlite3.connect(self.db_name) as conn:
            conn.execute("PRAGMA foreign_keys = ON;")
            c = conn.cursor()
            c.execute("SELECT CategoryName FROM Category ORDER BY CategoryName")
            for row in c.fetchall():
                self.list_categories.addItem(row[0])

    def add_custom_category(self):
        name = self.input_new_category.text().strip()
        if not name:
            QtWidgets.QMessageBox.warning(self, "Input Required", "Enter a category name first.")
            return
        try:
            with sqlite3.connect(self.db_name) as conn:
                conn.execute("PRAGMA foreign_keys = ON;")
                conn.cursor().execute(
                    "INSERT INTO Category (CategoryName) VALUES (?)", (name,)
                )
            self.input_new_category.clear()
            self.load_categories()
            self.load_category_list()
            self.statusBar().showMessage(f"  Category '{name}' added.", 3000)
        except sqlite3.IntegrityError:
            QtWidgets.QMessageBox.warning(self, "Duplicate", f"'{name}' already exists.")

    def remove_category(self):
        sel = self.list_categories.currentItem()
        if not sel:
            QtWidgets.QMessageBox.information(
                self, "No Selection", "Select a category from the list first."
            )
            return
        cat = sel.text()
        with sqlite3.connect(self.db_name) as conn:
            conn.execute("PRAGMA foreign_keys = ON;")
            c = conn.cursor()
            c.execute(
                "SELECT COUNT(*) FROM Item JOIN Category ON Item.CategoryID=Category.CategoryID"
                " WHERE Category.CategoryName=?",
                (cat,),
            )
            count = c.fetchone()[0]
        if count > 0:
            QtWidgets.QMessageBox.warning(
                self,
                "Cannot Remove",
                f"'{cat}' is used by {count} item(s).\nReassign or delete those items first.",
            )
            return
        dlg = ConfirmDialog(
            f"Remove category '{cat}'?\n\nThis cannot be undone.", parent=self
        )
        if dlg.exec_() == QtWidgets.QDialog.Accepted:
            with sqlite3.connect(self.db_name) as conn:
                conn.execute("PRAGMA foreign_keys = ON;")
                conn.cursor().execute("DELETE FROM Category WHERE CategoryName=?", (cat,))
            self.load_categories()
            self.load_category_list()
            self.statusBar().showMessage(f"  Category '{cat}' removed.", 3000)

    def toggle_dark_mode(self, state):
        target = "Dark" if state == QtCore.Qt.Checked else "Default"
        idx = self.combo_theme.findText(target)
        if idx >= 0 and self.combo_theme.currentIndex() != idx:
            self.combo_theme.setCurrentIndex(idx)
        elif idx < 0:
            self.apply_theme(target)

    def apply_theme(self, name):
        self._current_theme = name if name in THEMES else "Default"
        style = THEMES.get(self._current_theme, THEMES["Default"])
        app = QtWidgets.QApplication.instance()
        app.setStyleSheet(style)
        self.setStyleSheet(style)
        self.chk_dark_mode.blockSignals(True)
        self.chk_dark_mode.setChecked(self._current_theme == "Dark")
        self.chk_dark_mode.blockSignals(False)
        self._update_kpi_cards()
        if HAS_MPL:
            self.render_analytics_graphs()
        self.statusBar().showMessage(f"Theme applied: {self._current_theme}", 3000)

    def handle_backup(self):
        ts = datetime.now().strftime("%Y%m%d_%H%M%S")
        path, _ = QtWidgets.QFileDialog.getSaveFileName(
            self, "Save Backup As", f"smartstock_backup_{ts}.db", "Database Files (*.db)")
        if path:
            try:
                shutil.copy2(self.db_name, path)
                QtWidgets.QMessageBox.information(self, "Backup Successful", f"Saved to:\n{path}")
                self.statusBar().showMessage(f"Backup saved to {path}", 5000)
            except Exception as e:
                QtWidgets.QMessageBox.critical(self, "Backup Failed", str(e))

    def handle_system_reset(self):
        dlg = ConfirmDialog(
            "WARNING\n\nThis will permanently DELETE all inventory items.\n"
            "Categories will be kept.\n\nAre you sure?", parent=self)
        if dlg.exec_() == QtWidgets.QDialog.Accepted:
            with sqlite3.connect(self.db_name) as conn:
                conn.execute("PRAGMA foreign_keys = ON;")
                conn.cursor().execute("DELETE FROM Item")
            self.load_table_data()
            self._update_kpi_cards()
            QtWidgets.QMessageBox.information(self, "Reset Complete",
                                              "All inventory data has been cleared.")
            self.statusBar().showMessage("All inventory data wiped.", 5000)


# ─────────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    import warnings
    warnings.filterwarnings("ignore", category=DeprecationWarning)

    app = QtWidgets.QApplication(sys.argv)
    app.setStyle("Fusion")

    is_test_mode = "--test" in sys.argv
    window = SmartStockApp(is_sandbox=is_test_mode)
    window.show()
    sys.exit(app.exec_())