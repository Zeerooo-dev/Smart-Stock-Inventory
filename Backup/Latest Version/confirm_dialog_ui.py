# -*- coding: utf-8 -*-
# SmartStock Inventory System – Verification / Confirmation Dialog

from PyQt5 import QtCore, QtGui, QtWidgets


DIALOG_STYLE = """
    QDialog {
        background-color: #ffffff;
        border-radius: 8px;
        font-family: 'Inter', 'Segoe UI', sans-serif;
    }
    QLabel#dlgMessage {
        font-size: 14px;
        color: #434655;
        font-family: 'Inter', 'Segoe UI', sans-serif;
    }
    QLabel#dlgNote {
        font-size: 11px;
        color: #737686;
        font-family: 'Inter', 'Segoe UI', sans-serif;
        letter-spacing: 0.05em;
    }

    /* Cancel (secondary) */
    QPushButton#btnCancel {
        background-color: #ffffff;
        color: #505f76;
        border: 1px solid #c3c6d7;
        border-radius: 6px;
        font-size: 13px;
        font-weight: 600;
        padding: 0 20px;
        min-height: 38px;
        font-family: 'Inter', 'Segoe UI', sans-serif;
    }
    QPushButton#btnCancel:hover {
        background-color: #e1e2ed;
    }
    QPushButton#btnCancel:pressed {
        background-color: #c3c6d7;
    }

    /* OK / Confirm (primary) */
    QPushButton#btnOk {
        background-color: #2563eb;
        color: #eeefff;
        border: none;
        border-radius: 6px;
        font-size: 13px;
        font-weight: 700;
        padding: 0 20px;
        min-height: 38px;
        font-family: 'Inter', 'Segoe UI', sans-serif;
    }
    QPushButton#btnOk:hover {
        background-color: #1e56d4;
    }
    QPushButton#btnOk:pressed {
        background-color: #1748b8;
    }
"""


class Ui_Dialog:
    def setupUi(self, Dialog):
        Dialog.setObjectName("Dialog")
        Dialog.setWindowTitle("Confirm Action")
        Dialog.setFixedSize(400, 300)
        Dialog.setStyleSheet(DIALOG_STYLE)
        # Remove standard title bar / frame for a card-like look
        Dialog.setWindowFlags(
            QtCore.Qt.Dialog |
            QtCore.Qt.FramelessWindowHint |
            QtCore.Qt.WindowSystemMenuHint
        )
        Dialog.setAttribute(QtCore.Qt.WA_TranslucentBackground, False)

        root = QtWidgets.QVBoxLayout(Dialog)
        root.setContentsMargins(0, 0, 0, 0)
        root.setSpacing(0)

        # ── Header ────────────────────────────────────────────────────
        header = QtWidgets.QFrame()
        header.setStyleSheet("QFrame { background-color: #ffffff; border-bottom: none; }")
        header.setFixedHeight(52)
        header_layout = QtWidgets.QHBoxLayout(header)
        header_layout.setContentsMargins(20, 12, 14, 8)

        warn_icon = QtWidgets.QLabel("⚠")
        warn_icon.setStyleSheet("font-size: 17px; color: #ba1a1a; background: transparent;")

        dlg_title = QtWidgets.QLabel("Confirm Deletion")
        dlg_title.setStyleSheet(
            "font-size: 16px; font-weight: 600; color: #191b23; background: transparent;"
        )

        close_btn = QtWidgets.QPushButton("✕")
        close_btn.setFixedSize(28, 28)
        close_btn.setStyleSheet("""
            QPushButton {
                background: transparent;
                border: none;
                color: #737686;
                font-size: 14px;
            }
            QPushButton:hover { color: #191b23; }
        """)
        close_btn.setCursor(QtGui.QCursor(QtCore.Qt.PointingHandCursor))
        close_btn.clicked.connect(Dialog.reject)

        header_layout.addWidget(warn_icon)
        header_layout.addWidget(dlg_title)
        header_layout.addStretch()
        header_layout.addWidget(close_btn)
        root.addWidget(header)

        # ── Body ──────────────────────────────────────────────────────
        body = QtWidgets.QFrame()
        body.setStyleSheet("QFrame { background-color: #ffffff; }")
        body_layout = QtWidgets.QVBoxLayout(body)
        body_layout.setContentsMargins(0, 8, 0, 8)
        body_layout.setSpacing(8)
        body_layout.setAlignment(QtCore.Qt.AlignCenter)

        # Red circle icon
        icon_circle = QtWidgets.QLabel("🗑")
        icon_circle.setFixedSize(64, 64)
        icon_circle.setAlignment(QtCore.Qt.AlignCenter)
        icon_circle.setStyleSheet(f"""
            QLabel {{
                background-color: #ffdad6;
                border-radius: 32px;
                font-size: 28px;
            }}
        """)

        self.label = QtWidgets.QLabel("Are you sure you want to permanently delete this item?")
        self.label.setObjectName("dlgMessage")
        self.label.setAlignment(QtCore.Qt.AlignCenter)
        self.label.setWordWrap(True)
        self.label.setMaximumWidth(280)

        note = QtWidgets.QLabel("This action cannot be undone.")
        note.setObjectName("dlgNote")
        note.setAlignment(QtCore.Qt.AlignCenter)

        body_layout.addWidget(icon_circle, alignment=QtCore.Qt.AlignCenter)
        body_layout.addWidget(self.label, alignment=QtCore.Qt.AlignCenter)
        body_layout.addWidget(note, alignment=QtCore.Qt.AlignCenter)
        root.addWidget(body, stretch=1)

        # ── Footer / Button Box ───────────────────────────────────────
        footer = QtWidgets.QFrame()
        footer.setFixedHeight(64)
        footer.setStyleSheet(f"""
            QFrame {{
                background-color: rgba(243,243,254,0.6);
                border-top: 1px solid #c3c6d7;
            }}
        """)
        footer_layout = QtWidgets.QHBoxLayout(footer)
        footer_layout.setContentsMargins(20, 12, 20, 12)
        footer_layout.setSpacing(12)
        footer_layout.addStretch()

        self.btnCancel = QtWidgets.QPushButton("Cancel")
        self.btnCancel.setObjectName("btnCancel")
        self.btnCancel.setCursor(QtGui.QCursor(QtCore.Qt.PointingHandCursor))

        self.btnOk = QtWidgets.QPushButton("Ok")
        self.btnOk.setObjectName("btnOk")
        self.btnOk.setCursor(QtGui.QCursor(QtCore.Qt.PointingHandCursor))

        footer_layout.addWidget(self.btnCancel)
        footer_layout.addWidget(self.btnOk)
        root.addWidget(footer)

        # Wire standard accept/reject
        self.btnOk.clicked.connect(Dialog.accept)
        self.btnCancel.clicked.connect(Dialog.reject)

        QtCore.QMetaObject.connectSlotsByName(Dialog)

    def retranslateUi(self, Dialog):
        Dialog.setWindowTitle("Confirm Action")


# ── Standalone preview ────────────────────────────────────────────────
if __name__ == "__main__":
    import sys
    app = QtWidgets.QApplication(sys.argv)
    dlg = QtWidgets.QDialog()
    ui = Ui_Dialog()
    ui.setupUi(dlg)
    dlg.show()
    sys.exit(app.exec_())