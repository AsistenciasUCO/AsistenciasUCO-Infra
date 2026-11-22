"""Pruebas del generador del catalogo MessageUcoLab (python -m unittest test_build_message_catalog)."""
import importlib.util
import os
import unittest

_spec = importlib.util.spec_from_file_location("bmc", os.path.join(os.path.dirname(__file__), "build-message-catalog.py"))
bmc = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(bmc)


def row(code):
    return (code, "SUCCESS", "BAJO", "x")


class RemoteCodesTest(unittest.TestCase):
    def test_ok_largo_usa_prefijo_suc_y_continua_el_contador(self):
        out = bmc.remote_codes([row("OK_ASISTENCIA_001"), row("OK_ASISTENCIA_002")], {"SUC_X": "SUC003"})
        self.assertEqual(out, {"OK_ASISTENCIA_001": "SUC004", "OK_ASISTENCIA_002": "SUC005"})

    def test_rpt_largo_usa_prefijo_inf(self):
        out = bmc.remote_codes([row("RPT_ASISTENCIA_GRUPO"), row("RPT_ASISTENCIA_FIN")])
        self.assertEqual(out, {"RPT_ASISTENCIA_GRUPO": "INF001", "RPT_ASISTENCIA_FIN": "INF002"})

    def test_prefijo_desconocido_detiene(self):
        with self.assertRaises(SystemExit):
            bmc.remote_codes([row("XYZ_ASISTENCIA_001")])

    def test_la_lista_de_exclusion_solo_contiene_contenidos_cortos_documentados(self):
        for code, motivo in bmc.REMOTE_EXPORT_EXCLUDED.items():
            self.assertTrue(motivo)
            self.assertTrue(code.startswith("RPT_"))


if __name__ == "__main__":
    unittest.main()
