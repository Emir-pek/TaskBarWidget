# =====================================================================
#  Taskbar Kedileri  -  pixel art masaustu widget'i
#  Bagimliligi yok: Windows'ta hazir gelen PowerShell + .NET Framework yeter.
#  Baslatmak icin "Kedileri Baslat.bat" dosyasina cift tikla.
#
#  BU DOSYA URETILIR: kaynak/catbar_tpl.ps1 + kaynak/win/*.cs + sprite
#  sheet -> python kaynak/mkdist.py
#
#  Bu betik yalnizca BASLATICIDIR:
#   1. Widget'in C# kaynagini (motor, cizici, masaustu penceresi, sprite'lar)
#      Windows'un kendi derleyicisiyle bir kez kucuk bir .exe'ye derler:
#      %LOCALAPPDATA%\TaskbarKedileri\TaskbarKedileri-<ozet>.exe
#      Kaynak degismedikce sonraki acilislar derlemeyi atlar.
#   2. O exe'yi baslatir ve KAPANIR. Arka planda ~110 MB'lik PowerShell
#      degil, yalnizca kucuk widget sureci kalir.
#   3. Exe herhangi bir sebeple baslatilamazsa widget'i bu PowerShell
#      surecinin icinde calistirir (yedek).
# =====================================================================
$ErrorActionPreference = 'Stop'
$LogPath = Join-Path $PSScriptRoot 'catbar-hata.log'

function Write-CatLog([string]$Message) {
  try {
    Add-Content -Path $LogPath -Encoding UTF8 -Value ("[{0}] [bilgi] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message)
  } catch { }
}

try {
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$KediCs = @'
using System.Collections.Generic;
using System.Collections;
using System.ComponentModel;
using System.Diagnostics;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Drawing;
using System.Globalization;
using System.IO;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using System.Windows.Forms;
using System;

[assembly: AssemblyTitle("Taskbar Kedileri")]
[assembly: AssemblyProduct("Taskbar Kedileri")]
[assembly: AssemblyDescription("Taskbar Kedileri - pixel art masaustu widget'i")]
[assembly: AssemblyVersion("1.2.0.0")]
[assembly: AssemblyFileVersion("1.2.0.0")]

namespace TaskbarKedileri
{
    // URETILDI: kaynak/mkdist.py (assets/sprites.png + sprites.json). Elle duzenleme.
    internal static class KediAssets
    {
        public const int CellW = 34;
        public const int CellH = 33;
        public static readonly string[] Names = { "dogis_angry_1", "dogis_angry_2", "dogis_crouch_1", "dogis_crouch_2", "dogis_pet_1", "dogis_pet_2", "dogis_stand", "dogis_walk_1", "dogis_walk_2", "dogis_walk_3", "dogis_walk_4", "dogis_wave_1", "dogis_wave_2", "dogis_wave_3", "flower_1", "flower_2", "flower_3", "fx_anger_1", "fx_anger_2", "fx_heart", "fx_heart_s", "fx_huff", "fx_spark", "fx_zzz_1", "fx_zzz_2", "fx_zzz_3", "giraffe_blink", "giraffe_idle_1", "giraffe_idle_2", "giraffe_lean", "giraffe_sniff_1", "giraffe_sniff_2", "maya_jump_1", "maya_jump_2", "maya_jump_3", "maya_lookup", "maya_rub_a", "maya_rub_b", "maya_sit_a", "maya_sit_b", "maya_sit_blink", "maya_sit_happy", "maya_sleep_a", "maya_sleep_b", "maya_stand", "maya_stretch", "maya_walk_1", "maya_walk_2", "maya_walk_3", "maya_walk_4", "maya_yawn", "sun_1", "sun_2", "sun_3", "sun_4", "tarcin_jump_1", "tarcin_jump_2", "tarcin_jump_3", "tarcin_lookup", "tarcin_rub_a", "tarcin_rub_b", "tarcin_sit_a", "tarcin_sit_b", "tarcin_sit_blink", "tarcin_sit_happy", "tarcin_sleep_a", "tarcin_sleep_b", "tarcin_stand", "tarcin_stretch", "tarcin_walk_1", "tarcin_walk_2", "tarcin_walk_3", "tarcin_walk_4", "tarcin_yawn", "zilli_jump_1", "zilli_jump_2", "zilli_jump_3", "zilli_lookup", "zilli_rub_a", "zilli_rub_b", "zilli_sit_a", "zilli_sit_b", "zilli_sit_blink", "zilli_sit_happy", "zilli_sleep_a", "zilli_sleep_b", "zilli_stand", "zilli_stretch", "zilli_walk_1", "zilli_walk_2", "zilli_walk_3", "zilli_walk_4", "zilli_yawn" };
        public static readonly int[] Xs = { 0, 34, 68, 102, 136, 170, 204, 238, 272, 306, 0, 34, 68, 102, 136, 170, 204, 238, 272, 306, 0, 34, 68, 102, 136, 170, 204, 238, 272, 306, 0, 34, 68, 102, 136, 170, 204, 238, 272, 306, 0, 34, 68, 102, 136, 170, 204, 238, 272, 306, 0, 34, 68, 102, 136, 170, 204, 238, 272, 306, 0, 34, 68, 102, 136, 170, 204, 238, 272, 306, 0, 34, 68, 102, 136, 170, 204, 238, 272, 306, 0, 34, 68, 102, 136, 170, 204, 238, 272, 306, 0, 34, 68 };
        public static readonly int[] Ys = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 33, 33, 33, 33, 33, 33, 33, 33, 33, 33, 66, 66, 66, 66, 66, 66, 66, 66, 66, 66, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 132, 132, 132, 132, 132, 132, 132, 132, 132, 132, 165, 165, 165, 165, 165, 165, 165, 165, 165, 165, 198, 198, 198, 198, 198, 198, 198, 198, 198, 198, 231, 231, 231, 231, 231, 231, 231, 231, 231, 231, 264, 264, 264, 264, 264, 264, 264, 264, 264, 264, 297, 297, 297 };
        public const string SheetB64 =
            "iVBORw0KGgoAAAANSUhEUgAAAVQAAAFKCAYAAABCTqdeAAA1sUlEQVR4nO2df5RV1X32n4u8SxN8I06ljohVCFQyEYIFbADjCyTv"
            + "G1RSldgax0wglSCitTCCgjVZrraJU8CBsBCpL3mL3jiprbUYUclqalxpQRNFjVKcvCBoo4IOQXyXFLJqOe8fd/adffc9P/beZ59z"
            + "9p15PmuxuHPOPmc/d5+zn/vdP87ZACGEEEIIIT5Rsjlo9IjhQdj2vW+9Y3U+W3zRQWrhdanFl/Kgjuy1GB80esTw4LQhH4vc/8HR"
            + "Y7kUjC86SC0+XRcfKq4v5UEd+WgxSpwkIK2YRtNBavHpuvhQcX0pD+rIT4u2YBMBNkIaTQepxafr4kPF9aU8qCNfLYNsBI05a5jV"
            + "Ptf4ooPUUuR1Ma0spw35WGTXgCt8uU+pwyw/Gy1WhrrnQE/svrwKxRcdpBZfrosvFdeX8qCO7LUMthFxoOfXAIDd7XNrtrd0PmBz"
            + "Omt80UFqeeKeBfi9r90NAHjxwRUAUPP35bfen4sOncoSl8YVvpQHdWSvxcpQd/yvSzD0gpF123e3z8WRXfux/OB7udyoPuhIai7m"
            + "MfBRZP5h/N7X7q7enAL5Zr1k/NgBZWRy/mF/52Xs1JG9FitDBYAju/Zj6AUjMWnj3wMAXlj4hziyaz+A+MggC4QGwQsL/zAXHTr9"
            + "daNHDA+KHDXNMv8odt9xJ9ANTFrbic2X/08AwLwn/gkvLG7H7jvuxOf/93256Dil+6TIynJK90m5V1wA2Pv4bgDA6C+1VLflrYE6"
            + "stNiZagiKtw15Bg23zq78hnHcIGIFl/6N5vTWusQGqoc7d2XoQ7dwQ8x6FHUqGlW+cdxfOx/Aai9LpvHzsbxMf+Vl4Qqp3SfFGrs"
            + "QP4Vd++e14GxJ1c/jx7zyVzzp47stVgZ6ufLW/HB0WN1RjZp49/DdDpCGnzRkUQRplZk/pffen/odbl44XdzvS6+GLsv5UEd2Wux"
            + "bvIT4js+VVwyMNCaNiWal2IKwQdHj0WmFfvGnDXM+Rw/X3SYUPTUrTzyb8TrkiW+lAd1eKxl9IjhwfsHu4PRI4YH4nPYP3l/FpXF"
            + "Jx0Tz/9kMPH8TwYHt/5VNb/RI4bX/H1w619V07m+SYvMP0yPL9eFOux1yMcUqSOr8rDRIh+TdG7tCPX5F56u/i1/VlHTuTYRH3SE"
            + "8a8b/7T6T/5bEPdL2Oj5x12X624/XpP24fLqmnR53R/UoadDPaYoHSJdFhFqlmWi3Yd6yZfXhn7WSe8SX3SEETbtQp7rmOWg0MUL"
            + "v1szki3MNK/8467LJV+OT08d/ujISosv5WGjxURPoqGq7jx50g9x7M0fJp74p/+wuJreBb7oiEKddgEg12kg6kh23tNQ5HIWn8PY"
            + "99qLuKbth5ldF+pIp0M+5vTmjYXpyLLeZlkmRqP8p3z8E3h19wtaaT/4adnk1Eb4okMgRpPlJjaQ32hy0fkTv5k8aWbREvoFOuWo"
            + "Zag24fc/rah/JDQtvuiQRwr3HOip9k+KyFTmg6PHcNqQj2HS6N8BACdzQYvOP4xLvry22mLQuU6TJ83Ex879A+rIQUfY56RjdFp/"
            + "pjp8KA8bLSbptCqXbcewaKJPnjTTSf+dTzpsOu77S/5ResQveJy2SjNqaTWdS03UUa/jXzf+KS5e+N3CdfhQHmm0iHJM0qLd5BfN"
            + "ybeHnKN7CPa99iJGfer3tNM3kg5T9r32ohf5h/0o8eXb/ZO9b71Tap59OwD7YITUlmMSxk9Kzbvzp0bpj7251DSLhtBh2v0gmhiu"
            + "HgG1HQVV+1kB4OKF302t6TcvPFb9rKtNPsYV1BFNnjNeVHwsD8B9mWgZ6t633ildvPC7Vr9wLqMfX3QAiB0dVBGjhcLMXBiYSf6y"
            + "BtH8k3FdNsfe/GFoU0puQuUBddjpyNrIii4P+fu51mK8SN/JZ4zqE3ZoHwBA3ZbHO0CL1GHThyn6bIrqQ3WZfxRFXxfqoI6itfDl"
            + "KJZcPGu+8TEub5Si8yeNQZhxiPtgNFDdd/IZozA6w1kgPpFlmVitKUUIaXz2vvVOSURmQK+B9PPBqzgzBdKXCSNUQ9QLAvQ1FwTq"
            + "/v6UP2kcksyDuIeGmpKwm1RuNvT3/Eljs/etd0oDpemv+wOTpkz6laH+5tA+fPCbvr9dTVFKS9GRQdH5k+LRvQcGyr1i8j1N0moX"
            + "3OgRwwPZrE47uW+QI26fa5J0qOmzWMtJzV/OJ+uyKDp/E10+3h8DRYdJHkXrKTp/F+kFRhGqqLym+1wTlVdev6xh+cvRsLw/C01F"
            + "52+iS2cfdeSff5q0tjRSedikJ4QQQgghxD+smoNR87LyeNKiiHypgxCig3HFE+/ijOKDo8cye0VcEflSByFEF+Nn+XXfAO+yQheV"
            + "L3UQQkzQfvTUpBIDcLaOdVH5UgchxBSrZ/nHnDXMal9aisqXOgghOlgZ6p4DPbH7sqrMReVLHYQQHawM9Yl7FuBAz69xoOfXeOKe"
            + "BXV/x1X0NBSVL3UQQnSwfpb/xQdXRP4tVuPMgjT5vtF6R7Uv8byu76QaqCnq+/uqgxDi4H2oex/fjb2P767ZlnUlvnjhd6v5ykt6"
            + "mOQrm2veOt5ovSMQ/9JqEBRxHQghtaQy1L17XgfGngyMPTl0Tfis2Hzr7Gq+m2+drXXMytZPB2mjUhc6VFyYqu11yMLYCRnIGL1t"
            + "Sp6u88HRY3UmMu+erVDTpJ0D6SLfla2fDm7r+rfCdchabLsfXF4H1Uhd/+AQMtDoV+9DDcOFmbrSAQBCS1HmJcpDROyMTglxh1aT"
            + "X0RFYhrOB0ePRaYV+8acNSz1pPK0+boyU1c6XEXJaXXI5XJe13dK4p+pnrmXrSncjH3QIOObHuIpo0cMD94/2B2MHjE8EJ/D/sn7"
            + "XT0pZZLv6BHDg4Nb/yoQEaErqKOWuZetCR65tzso0kB80CDjmx6SP9oRqrwOvPz5utuP16R9uLy6Jl3aCNUm35MnXYH7f/q+bbbU"
            + "ocnI85vwpcsvDY3K8jIVHzT4rIfki3Yf6iVfXhv6ufJ3fPo0mObrMm/qiOes807FWeedCuBSAKgxiy9dXtn2wJNLMu0r9kGDz3pI"
            + "vmhdWDkymjxpZk1kpLLvtRdxTdtSyOltR/pt8gUqkVuafKkjHDnCuqX9OgAVA9nxo3/HyPObav5+/ImnkIVx+KDBZz2kWFJP7PeR"
            + "05vHlnx4ZV1/0jH3sjXBly6/FOLf/l8exgO3fAEA8NN7/wgAqn9nhQ8afNZDiseoyX/szR9WPycxedJMfOzcP7AWZptvVgY2kHXM"
            + "vWxNIEdfB974EABQXnwJDrzxId5cfAnOOu9UvLn4kswiMR80+KyH+IFRk3/ypJkAkFtT0ybfrFYLGOg6VAMR3Pj0bdXP3xr1Lez/"
            + "5WGMPL8J6zofAgCnJuKDBp/1kOLp9xP7iRt6TSC4pf26ajQGAPfNXIkbn74N981ciQNvfIipX/wdAMDd624Q6ZwNwvigwWc9pHi0"
            + "DfU3LzxW/aw7aiwfY4tNvllAHX0G8qXLL60OuACoGgcAHHjjQ+z/5WEAyKSZ64MGn/WQYrGKUI+9+cPQ5qbc3M+CovKljnpEv+GB"
            + "Nz6sae6KZi2QfdPWBw0+6yH5o2Woe996p9Q8+3aMHjE8OPmMUQCAi2fNx28O7QMAiG1yegBonn17KnG2+bqGOqIRkZc8MJO3afig"
            + "wWc9JD/65bQpki0jz2/CgTc+xLrOh/D4E09VDUQwetaIYPSsEZk+FZSkIS8dunqy0nFw4rRA/p8UCweliDZi3qU8Wj161ogATwBA"
            + "Xx/iRV89XxwS7N32lvPpUzoaRs8aEWSpw1RPrxanOv72t1sC9e+vvLe7kEj44MRpQfPO7SXxfxEabFhz7tQAAJa8uaMkf7Y9Hw2V"
            + "aCMGYNTm63+2bsXjXQCeqHwGgF/tPlSohotwfqY6TPW41iEi0md+VXlHwzO/eh/TzzkdB8/J39DU6LhRTHXNuVODxdN7H7x4BjWf"
            + "bU2VhkqMiOoL3H7iHlz01fOrxnHgxV8jq6hQ1dCbT3DRV4Gff/+XuAj56AjTIyLjn3//l7joq72Gvtu9DtWwvvLe7hLec3V2ey2N"
            + "YKRhVM00JTRU4oyff/+X1c9Zm9hA1yFHqF95b3fpb3+7JZh+zukA8jc1oUU0+YvQYMOSN3eUaiJTAGuf+XE+Tf7RI4YHH/wGwNuV"
            + "EeXTTu4bRR4NVPZJaV2+EKSIfKnDnCLNS2Yg6Gjeub3PRN8Dpp9zetVcs8ozTovc7G8EMxXIpprWTAHDCPW0k+32paWofKmD+MxX"
            + "3ttdOnhOn5EVNSAF9JloI5mpQJhqWjMlhBBCCCGEENLvuWlqU3DT1KYgadtA0TGQ4Cg/IQ65aWpTcMt0Ua2agnt3HC6FbRsoOoQW"
            + "AJDzC9tWJK700FAJMSQLM7A5py86ks7ni7HLmoC+76ijR7dcaKiEGHDT1KZgzere1/QtRWglGzn7E1iy9HB1e+X/3uOeOVx3PgCQ"
            + "z6ljML7okI/12djl85qYuWm50FAJsaBn6yzcMR0YNntbXSVbsrRiVmpfpdguEKbYs3UWerb2nqvBdPhk7LZE6bEpFxoqISno2ToL"
            + "a1Zvq5pJ1QjikNL2bJ3VL3QUbewqcRGuavAibZhO03KhoRJiwL07DpewFMGa1duqlW3J0sOJBnZ01wkAwJALBlXTLll6GHdMr+wf"
            + "NntbTSVvFB0qRRs7EB81i3IT6aI0irJcsrQLd0xv1c7bixE2QhoNUWl1TAzoMzKgYmaCvoprZ2I+6JAjSwD4zjNdRsYuaxDmlcbY"
            + "VT3yuWrMVkOT0KVbNoxQCbFAjnRMUCsrgFQRYZSO/zZlDwDgP58dU7N96DdeD92eRoccLesau+DorhPVMhERYZofmDDkqFn3RyfM"
            + "VHX08I39hFgiKtjRXSdqIr8whlwwKNRM5fPkoUPnPLbHqn2iQMXYhbnLDP3G6xj6jded/8DIWuQ+WB2jj9Okq4eGSogjju46gTFX"
            + "HcaYq+qNRd2e1vySdJzX/Fs4r/m36vap213q8MHY5XMIU1W7IKJMXsXme7DJT4hD9vxjeBQkb8/KSE3JWsfRXScw4aqKeavlIkxd"
            + "bM9Ci2m3jKrJBhoqISmRm4hhxhDV1M9Sx8t/MbROz5ALBqUyi6zI0tjFQJScR5TJu9BEQyWEOKXRjF0MQrnQREMlxCHCTMZcdbha"
            + "QeXPIk3WzW1fdPjGkAsGhZq8KzgoRUhKxOCFXEFl45INTRA36t/oOmTE+Sd880j1szpol0eXSNz3jNJkUzY0VEIcIkb6VdTosD/r"
            + "8NHYZVSTj9JkA5v8hDjm1T/pwJirltdsK6LP0AcdR3edwIRvHqnLN+8fGFmPaqIuNdFQCUlB75zJ4C/nDQVQiX6OP61nXC6fBvJF"
            + "RxhFG7uYPiXKJszkXRk8DZWQlAgz69uyHHhS+7h+pcNnY5dRTT5Kn6kmGiohDlBfvBH1oo2ju07gzs1HMjMOH3T4YOw6yCYa9tgs"
            + "YK6JhkpIjuQ18JJE1jp8MHaVOzcfkf6qNXn5VYZptNBQCcmAOMNas7oplzfRN4KOPH9gTN6CZYsfP5eENDhx79mkjnjWrG6qe5t/"
            + "UVrSQkMlhBBH0FAJIf2WvCP2VH2oa86dGix5c0dJ/O9KFLFn/zvv1zWdRg4/ndcmB+IGXgR59BlSR3E6rA11zblTg8XTvwA8g+r/"
            + "Lkz1nvvKAQDcemMbTcAC2TzDzDVP1PwHorGrL+AIW16DOvqPjtSj/IunfyG1CME995WDr7de1ftXOWhEU/UlWhdmVqSJibx9MvYs"
            + "yyOsQqpvdMrrRSDUUYwOa0Nd8uaOkohO1z7zY6Q1kVozbcwIdc25UwPxf5Gm6oOZ+qRl5PDTS1maelI/XV4RGHUUryP1Te7SPPpD"
            + "c98XM5Upysx8afLnEaGaTvvJau4ndfipgxBCCCGEEEIIIYQQQohDbpraFMR1ACftJ4SQRsfJ26ZumtoU3DJdnKqp5u01wkSr0xcy"
            + "fruNyC8qj6T9hBBii5Wh6pqSmAfWs3UWerYCw2Zvs8nOSJcvxk4IGXgYG2qYaVWMqXcS7TOHa8yrZ+ssp4JVLYB/xk4IGZg4fcG0"
            + "WEZAfvs10IU7prdi2OxtTteM8cnYCSEEiHl9X9Qg0r07DpfWPfMRRs7+RE26NaubIP4JxN/feaYrC+2RyMa+ZnUTliw9XNXg2tgJ"
            + "kVnZOl574NUkbSPjQ5nkpSHUUGWDjDJW1bSAyhtb1Le4yOltTKyRjZ3kiw8VV/fceZtp0ebtQ5nkoSG2yd+zdRbumN7b59g7iKPz"
            + "wtawV2HZmqk8iBR2HrWbQeQPhL/8gNFp/2Zl6/jgtq5XYq9vFhVXnHPRspt7t6wPACBMy8rW8YGcLkmvK226aVzp8aFM8tag1Yfa"
            + "s3UW1qyumKrO26+FkUVFq6YUbezEb3youHL+H716BhYtuxkbVq2P1PnRq2dg8LhDvcdkY6ph5RKXj075meJDmeSpIdRQ791xuFQx"
            + "z23VwZwlSw8nrho44ZtHAFTWu3ZlpjJFGzvxlyIrbq1J1+/T056NqarlIvKRI3mhXy4XtfxM8aFMitAQGaHKpqpjpmOuOow9/9hU"
            + "/fzyXwzV1RCJr8ZO/MGHihtGn4GF7wOAIeOvw9FXHnKZbRWdcokrnyzKpegyyUNDbJNfGJq6fcxVlX5LYaBhn10ZmQ/GThoLm0qj"
            + "0/eqy+Bxh7T2q5XWpYYwijQ0H8okDw2Jr6wWfY5iBF8Y1p5/bKoaaxgu34Z9747DJTH4JDPmqsN1GqJMngwMBo87hNParorcf1rb"
            + "VRg87lBNpYkyGR3iIkETXJxDEBZ5Dh53KNZQxH4XZupDmRSlwdj15IhPRKJR0eiQCwY5M1YfjJ34RVileX/Xg7jgnP+O93c9WJc+"
            + "bl9/w6VBu2DIhG/g/V0PRl6X93c9iCETvtHwGozdRixupRppnKllQVHGbsLK1vGBGi2EbaOOgTHBfSDz1vc/h1krXo7cP2vFy3jr"
            + "+59reA3aj55GGZLYLjev5X7MrFBXLZTzVvW4wLQvZ2Xr+GDBrLt6m1l9I6tiNBW4y6pviDqS2Xb3BKt9hKTF6ll+YaJhxqlucz2R"
            + "vkhjNzUR0We1aNnNWLSsb3Bv8LhDWDTOfhSVOqI5/YKv1fwtBlsGjztUty8vZA0+UISe0y/4Gn72eF/5q9dF3tfIGowNVUyWV81K"
            + "jQzFIFKWE+mFDjlfWY8rYzedDK7bIW46NYU6aqmkW5947iyNI0mDmNuZxIZV6509oaRTLv29TIrSoNWxKEbZRRP76K4TePVPOqqj"
            + "7PIAkUBn4n0a5Oa+auyymS5ZejjTx03l/j+dvsCsOt+pI5yio8Ii8k/6Acvb4G3yz5qsNKR6fZ8aFapTm1ybmJiT+pfzhgKQjX15"
            + "pCbxtimXhA2sRO1TmbXiZWzD55w0P6mjniHjr9NKl+XkcVsNoqxcPh3kQ3mk1eGiXNJoMMlfS6B425MwMqC2L1M2rDyWN5F1nPTe"
            + "cpwyc2VNuiyMXb5RN6xajzlXfyE0XfPIsVrnE/0392+7y+hGoY5wDYB+hRHIFcc2InOpwSct8qOnplpc65DvsyLuDVlLUv6JEar8"
            + "EpKoSC9pvwuEDjUP2UyzNHa5TybtHD9bE6OOaEwrjDjG5dNSLjQAbh77dKHFxUtk0uqQ7y3bcsnzusQaqvpGp7h+0bxeixfXhBf7"
            + "stDh6skLQOq/sViJhTrc5w/YvWnJhQZXTe3sysPMyHwokyI1NMRjRGHGHvavkciy03+g6bCJQKKOFRG36cMGthqijrPRkFaLemza"
            + "N065KBNVg2m55H1dIiPUm6Y2BX85b2joO0XlEfa8nkDyRUeamxVwF5FQh3vk/rosX6mnk39RGqIoUotaLkXnH1cWxi6kPp2U9evx"
            + "hLEXreO2rldKG1atT2UAR195CBtWrcepFy4opZlfRx315yniWBfnUY9LG5Gl0ZL2WFfn8lGD7nWJ7UMNi/rURz7ziAx1dOSBGIiZ"
            + "c3U3Hn3kx6Gjjytbxwdzrv4CHn3kxzVNWNGv4/KXXhiS+qLgME3q9pWt44MPX7o/UNPqUH++BZHHRmmS99voUCduyxUgKmqOq1w2"
            + "zVuXGmq/e/LDCllqEXpsyKJMTH9QirwuoYaatLxIXs1rX3RE5l+9OHo3n2l6m3OZbLfRs7J1fLCs/CwAYFXblEQDFDf3svKzWFa+"
            + "DsCUmh8Tdf9tXUO0tagVR5jAomXh6fv231y33abiutLgqh/bh/JwpSNtmRSlIXYJFJMTZTGy7osOlUcf+TGAiqHE7VeJSm9K5SJP"
            + "qRuNNtkelVYHHSPV0Ru23xRRcWrPvT70XFH7a8ukb59ptGyrQc3HVocLLfL2InWE/eia6vDpuhBCCCGEEEIIIYQQQgghhBBCCCGE"
            + "EEIIIYQQQgghxBdMHkHLao11HzQQQkgc2g/D65hU1kbmgwZCCIki9m1Twpx03mZuurSwLj5oIIQQHRIjVGFQH716RuhLXle2jg+E"
            + "kYm1gdK8bdxXDYQQkkRkhBq3LouOUbl476cPGgghRJfEVU9loiJEsQ8IXy3QJT5oIISQMLQHpQaPO9S3OmXMftXIXDa7fdBACCFR"
            + "hBqqqyVp05zDBw2uEH28qrGHbRsIOgjprxg1+Yk96uyDomYkFKlDmLa61pa6baDgS3lQhzsdxS7KNACImn2gzlzIYw6vSx2mele2"
            + "jg8WzLqrJg+R/4JZdzV8t4wv5UEdxeqgoeaE3Pcrd0OI7XlN83Kpw1SvnMeHL91fNfPB4w4VNs3NZReIL+VBHcXpsDbUj149oxrt"
            + "FIUPGoD6C6b+sumS1lTy0iEvia379JpO/i6/v64uF1GRL+VBHcXrCDXU27peKcWty/3Rq2ckjrgD6ZaC9UGDCeqATx7RVpiBFKEj"
            + "SVMc7+96EEMmfCN1fur3j9KkEheNuCDv8qCOYnVYDUq5utnSUKQG9QK4mklgY/5Ci8vZDKY64gws6WadteJlbMPncPoFXzMXKuUR"
            + "9v0XLUMQ9aOsE40sWnYzbutaYKUn6u88yoM6itOhbahDxl+nlS5sQr2rkTpbDa7yl88lV8aD+7tD0zaPHKt1TnmgKGmkXb7wLjWY"
            + "6BDrk4vm1IZV6zHn6i9Y5f+zxztr8jZB1xQr9L0DwrQLJAlfyoM6itcRWmHUG07XyASyoW1Ytb56U5tEPi41yFpsTTWLSFAgLtLg"
            + "cYcSNbo2A1sdLrWIfO/fdpfV/RH1YyIjKox8PwrUKFbef+qFC4wi9aLKgzr80JEYoZoamThGGJr8RWyfrU+rIW3+tce7R3RfFGmm"
            + "Jjpca6l232xzcrpYwrsG6reZRkS+lAd1FKujzlBdCEj7HL0vGuS/k/TYmD6QrLOIqURFkKb1YNKt0SjkNZhKHW51xEaotiYhR4dq"
            + "E8s0SnShQUa3n1LupshCnw66OlxpsPkRSpu37Q+f3D/mQofKUTyUeO3DKKo8qMMPHblM7Le5MbPM32Q+W1JkmuaCmxzrwzsJZMS0"
            + "trTff8Oq9Tj1wgUlH6KPNPhSHtRRrI5YQ7UV4fLVea40ZG2qNv9UfUkXK0qHi/KWWxQmN+/B/d1Y1TYFpZOGlFa1Tal+N7FNbH/9"
            + "sW/WpXNNWL5R5Z10Hpsm5m1dr5ROvXCBdjmo/0Rr7sOX7k/9spoir8vK1vHB3kfbA6AyqKd+zzg98naXP7R5lUddk19tSsknjAqb"
            + "ozIVN6XpzZGFhspf67X6ZtX8syaq8procFERfOmnMkV078Tpz7JrhhBBaB+qWpFFdLdoWfhJ+vbfXLMtTeUsWkNeppqk0RcdvpOk"
            + "3+QHx0VZ9Bl4sd1djUajl1vkoJSoyH2fAfF3eNra/fINKZ9L3ReHSw02OtT0WaBTFr7o0EG3QriqOJUf0mgDtOm/d1EWq9qmhG5/"
            + "9JEfxx6XlaHkfV1sv2dUubkm7/IghBAyUNly2ZlezNekjlp80UEI0WTLZWcGwT98Oii68lKHnzoIIZqISht8uKXQylvV8cr/oA6P"
            + "dBCSJ3xjvwZbLjsz0hCCI5tjjSJqf9w5TXSI8+vqUNPZ6NDJx3Y/IY2M94v0icp+5ZPvph55tTnXlsvODK64vvKijC1AoB5bGjov"
            + "9lxh+5POaaJDnF9Xh5zORod8LFBflrblEXYuQhoNryNUUeGvuP6MaqWzjcjCzmXEGLc6MMZy6ZYvftutji9+21iCV9eFEKJHVD9c"
            + "WKWUm65h+9P053mnQ+kvttZh2e/sS3kQ4hteN/mvfPLd0hYguOJ69EZ0lfcRlobOKwVHNgf4f/8Xwb/fUdunCFS2H9kc1DQvx5wB"
            + "7DmEx753yLhp6Z0O/FklsvzeDfY6vvht4Ed/1tDlQYhvNMQNrPaxyZX1sYXfq0t/xcbrq59Lv/OdUtg5qKP/6CDEF7y/idWIRlRa"
            + "UWGv+Lu/BvatqTnmseWVJTFEBRaVN+x8jaJDpM9Kh60e1zp08yfERxriBq5WeqnSXvF3f13ZqVRamceWd9dU3rSVljr81EGIL3g9"
            + "yg/URlCAVGmHXBFbaQHgio6x1YhJPY9J/lnq0NVDHYTY09rSFLS2NCXeW7rpovDeUOWBjhpenW52orABEc38s9Shq4c6SKOSl5nF"
            + "nbezbSw2LN+EuPO3tjQFG5ZvQmfb2Nh0cXg5yq9OnxHNymoUlBAByXz+yt+qRE8br0dp6LySeu64wRDq8FMHaRyEmZ1y9lKgY37Q"
            + "tftw6HUVZnb87dVAuTsynW3+pnS2jbXS4Z2hyk/vVLcBfZXNoNLqnjus8lKHnzpI45C3memwYfkmoGN+aPS5YfkmAMCwWx5Fz7o5"
            + "VufPxFDlJU/kl/WK7VEv8I18eqd3vqUTlHNfgT+rq7zRTzMdcqdDOfcV19ebCHXQVPsTWZtZEsffXg2g17Bj9h9fZ59HZhFq35Id"
            + "lSWb5SWRo5Zxrpm47oAPn+up3/ij2nOHTSivmbielY49tWZEHck6SONy/O3VOHP5dnT2mpbKaW1X4d2OaVUzcxGl2kbIAhsNzg1V"
            + "GOdHr56BweMO9Rpr35pIH716RnVbnKmq2wJlmw1R5zZJSx3F6nCBGHCQK0rYtqzpzzpUM/vBzDHoGDkUyx++Etc+vacmbdw+l7SX"
            + "u6ufVaON22dCZhHq4HF9EYe8wJzYnmSq8t9iNPmKjddXBjI6kr+wiIL+ecuvq3MeTUf5qcNPHWkIG/zQHTihjsans21sjXnq7tPF"
            + "atqUuiy0+Lu2WZ/MomU3151LpVrZPvG72ucNbVJ+4nchz3fURZ136VqH7fzPga5DYDPVRu5LO3j31Gokdfzt1dZTZqgjmeUPX2m1"
            + "zxXie4VFoHH7TLD65YkzQdPljnWW7A19IickGlIrrBwFZfZkEHUUpkNuVraXuxObpyZ9ajrnow77c59y9lIAfWbuIk8fNGg1+VUD"
            + "dbVGvImZAr2V79/vCEQTE6jMZ1T55y2/BlD/zLjNM+u+6Ah75t6ljjTP8hd5XVzxg5ljsPiizXi3Y1pREvqVjq7dh0sod4caWnu5"
            + "GxuWA4s65qeOCG00VPLfhEUd8wFER6U2hp5oqMJMZRM9uD+8n6F5pF7hiAErHeRJ31c++W5JrryA+VuNbCtt0TrkJ4my0GGjx4fr"
            + "omLbPO24Zgvw8Dxc60IEdcTS2Ta22p1QBFnmH2moYUYq0DXOMH7/S+0AgJ893qmVXp4DuaV3XqJoJooBkVB6++aq5+gYC+w5ZD23"
            + "0TsdX/w2tvzRDfY6/u6vgR/Vz8E11lFgecgRiJjismDS0NC0Yz/VHHuuX9zwaeDpPdVmIDCfOix1hDHslke10mU1BzUvDbERqqum"
            + "vUCYqS41E8qleYpqM1V+bPHKJ98Nb8buOdS7jInd+kle6eh9OXQqHT+qvKQ67MGGRikPIMREUiDMY1HHfOOmHnXUIvdf6hqZSOvK"
            + "VNNqED9KYrtOGVQNVbefdMj467SFAcDRVx6qfv7Z453Gpgqg5o3uYZVWNpktQM3+ajrLiemqeSTq6E2XqMPQRNTv6UQH7E0VgNvy"
            + "sCTt5G2ZuMEJ6rDDxMjkY1xGqi406E7yHwzUTnfasGp9ZGJTM1WPOfrKQ9Wmvs6AlDzhO+0qn2HnMkJZpiOtDmsTUZYtSa3D4qk0"
            + "r66LY9KOLFOHO1OXI8S8NTh7ln/RsptjTTUNwlyPvvJQ7MR+GZeVzOZcSRU+aXQ6bL+NiUQdoztKH5YujZlFpbctD5O8w7CJQmRc"
            + "RUTU4UaDHCF2to1FJxDYmLuthrAoWSdKDe1DjWruy833tOhEqL4QV+F1IzKTc5rosI0M0+jQycd2vynVPkPMsa48PevmpI4IqSM7"
            + "mlfsqD69ldVbqOIIG+yL0jAIqLz9KauoNAyXZnrlk++WHvveIesVPF1R1VHwCp4DUUfX7sOl9nI3/uXGqWib3IKedXPQs24O2ia3"
            + "4KQhzaWThjSX2ia3VPeLbWI7AKdPBIXlHaVJ3t68YkcJAA7ePTU4ePdU4yeeWluaAvGkU3u5u+Z7qv+iNJ00pLmUVodcDra4itRt"
            + "z6MeJ+4xIP5eqUaoFYNbb/ToqA1ZRKai6Vp0Hxx1+KGjGpmVWzJJb3Muk+02elpbmoLy87sBAG2TWxKjSxF1lZ/fjfItACa31ERd"
            + "6v6uIfHTrMLO3dk2thrtAoDQpyL/qMmkiZJdaFDzj3tYQVAnNunZ+rQ0SjOfNBZREYOoEPL+sLcqhe1Lo0M9j8l2mzc92b4dKum4"
            + "NG+dUo81uUZqnlHXL0sNYfnY6iCEEEIIIYQQQgghhBBCCCGEEEIIIYQQQgghhBBCCCGEEEIIIYQQQsgAoLWlSetVYrrpGlWDT1p8"
            + "0EBIQ1Jk5RHvejzy4KOx525taQqOPPhoqvc4+qzBJy0+aCDEJwbpJhRvzN6wfFPsi3hbW5qCDcs3OX1hr+36MP1Ng09afNBAiG/E"
            + "LiMtSFN5sliyYMPyTUDH/NBKuWH5JgDuV070UYNPWnzQQEjRaBmqSpGVRyxtG2XwYv/xdc6z9kqDT1p80ECID2hFjmmWZE272JeL"
            + "JWn7gwaftPiggbjD1aoB/YU05ZEYoaqVR6zNAvRFJGHbsuLM5dux9ufzAADXPr2nZt8PZo4BACy+aDPe7ZjWrzX4RNz1z/PesMEX"
            + "MylKhxjzOP726mr3nKjzp5y9FOiYn/sqo0WStjy0B6VkVIMVf+dRYdb+fB46rtkSub/jmi1Vs+vPGgTt5e7qP5N9rom79j4aKRA+"
            + "gKo7+OqrDpsZNnKXjVg1VWwvahAx7HvYfLe8y8O4D1U1zzzNlNTjg5HF3QO+3x9y5ekEAnl7nuvAu9BR05o0TR9DnuUAuIuaiygP"
            + "q0EpwSlnLwXQdzPkwbVP78G1N3wa6G1qyxrUff1ZQxRFXBMfNSThi5n4okPlBzPHOOm2CovmdL5D3A9MEeiWR6KhRq1F3V7uxobl"
            + "wKKO+ZlGH/H5b8KijvkAoiMgF4MfPmjwSYsPGogets31jmu2AA/Pw7Up8w1ttQCB6IYKW1Y7yU8628aia8WOVLpM0S0Ps7DZEB9G"
            + "tvuTBp+0+KAhiajKEzdwpu53MSNCR4MrHfJ1aS93Y8GkoaHpxn6qOelUAPpaG4s65muXg8m9IRuryXHNK3YYa8mjPGIjVFnMsFse"
            + "1cow64nbPujwQYPABy0+aBDIBhZVeVSiKvEpZy/FhuUwHum20eBKh9x6SNtyTGum3a8dTEwv93Ga/NDpknd5RBqqjZmKtC4rTlod"
            + "ct+T7TQUVxrEdldzQFketZqAYge/fNHgKv88+yvjBjRlhKkBeh6Td3kk9qGaVBj5GNlUXcynS6vDdMQvCw2Au8EFlkcfLiuNzPG3"
            + "V1s1tYvU4Zo0+eo2oxuJpPIINVRXN4eoLLYVN60OF5GyDxp80uKDBpkkPTamD+TTPZEltt9bYPv91QHLtDpUetbNsZpXnVd5xEao"
            + "aUTIkUjzih2lg3dPtZ4cbKtD1lDXl2Jo7i40CNJGZQO5PHRbO64rso0OVxpMzK16XTEn1Y9Jf5mJkXd5WD0pZYN4oqrIV7d17T5c"
            + "yuOpIZ38iy4LVU/R+ZuUh07aNBGm7rE+XMMoul87iLbJLThpSHOpbXILetbNQc+6OdVtYvu/3Di1Lp1rwvIVekzyszX6rt2HS80r"
            + "dmiXg/pPeJfO+3xjI9Sedelc3RW2OnzUkDYydKklDUWXhzywJT/+HJeXKTqVN05Hmvojn6NRo0XRGonTn3VLIm9CDVW+yeU+i/Lz"
            + "u0NP0ja5BUD4/L40N4ILHT5qiJoYX4QWU4ouD5fTYOJIKiddHXmYus8k6TcpHxdlUTXwckua00QSGaGKG6b6GQAmt4SGu9X90lSY"
            + "mu292DQv0+oIuwCmOrLQYKMjKy2NVh5y/lmhU3F90aGDrpG4Mpz2cjdQbnF/76dE/MCr3P/CkdjjsjZiQgghhBBCCCGEEEIIIYQQ"
            + "QgghhBBCCCGEEEIIIYQQQgghhBBCCCGEhNOwb7EhhPjNxCkzal4cs/PZn4T6jW66RiBxTSlCSONRtJlNnDIjaG1rAwBcOmgQnjpx"
            + "AgAC9fwinZQmNJ0rsi4XGioh/YyizUzO34beY52bah7lQkMlpB/hq5ldOmgQ0HtuNb9LB1VWYpo88UI8v/Mll9lWyatcaKiE9HOK"
            + "NjMpykOYqVX3Z5R/FFmUi1NDDVsJUneVSuogxD1PnTiB9hu/jqfu+5tQM/vUDXPRed/f1JhZmig1bSToQoMOWZm8s1VPW1uagg3L"
            + "N9WsBCnWTN+wfFNuq0NSR7IuNe+wbVkwccqMQO3sD9tGHXY6wsxs4YS1OPPsc7Fwwtq69HH7+hOuTF6HyAjVJpI6/vZqAJUF2Tql"
            + "MPr426utV/ikDncIkz/+9upq3sLkTzl7KdAxPzM9E6fMCMpz59YMBMid/20ZRiPUQfIi1FBFJQOgVelr0sdgaiLU4R5XJi+iKJNK"
            + "L5pRrW1taG1rC+Tttk086khm/yNDrfYRczIflPrBzDFYfNFmvNsxLeusqCMGlyavNKESK71uk8vURKgjmY0vL675Wwy2PHXiRN2+"
            + "vJA1+IBLPdqGatvH1nHNFuDhebjW5mDq6PcsnLAWH5/yi8rACHWk0tFrvIlmnaWRJWlQ5nZG0lUuO3vIQKdcXJVJqKGK9cY728ZW"
            + "I5YFk4aGnmDsp5pjM/jFDZ8Gnt5T6aMDAMzXFkcdZkSZvBqZqmuiy/vby91WMxBsB1JGXn0E+x/5DIDFNodThyFFR4VF5J/UInBp"
            + "8JERap2JpECYx6KO+caVlTrikU00yuRVwvS3l7uxYfkm6Bi8/IsvmqWfnRbehTFq1KjYc91+513Y+HJfs6srMXfqMGHyxAu10mU1"
            + "B7VoDaqZZq0ldpQ/rXEIxECIDdQRjjBSF5ray9345//4L5z/ra/j8x8/SeuYEBOxRphH2wMPGDfzqKMPW/MQaV0YmisN4odJ7HMx"
            + "JzaP8sjtSSnbpiR11OPS3IWZmuJybl+aZiB1hGNiHvIxLqPEtBqU8kw1OOeiPORunCgtiYY67JZHjYXI9Kybk+p46qglykxNdQkd"
            + "nW1jrU3VJS4HIQaiDteT1+UI0XK2gxWuDD2j8pAJNfjkPlTMsTaRnnVzUkeEA12HzgMFNnrkYzoxpzpQZVpGNr/8Mq4qEHW40RAR"
            + "IRrPsbXVEBUlp5lC5qo8usrlxO6cxAi1+7WDaJ/cAvmpGqC2ydra0hQsmDQU979wpC5dGuTzNq/YUcKK5rr9UXrCtrugiPLI+gGA"
            + "Ybc8ivItvVGrZj6izxCwv2Gf3/lS6oiQOrJDGIjJHNss8hdk/Xy/CVFa+LapBkGYKlAxb9mgXXVnmP74CBPZt28fntu+vXrzy6Yw"
            + "ccqM4LPTpuG57dtrjEI0yVxWEtWQ5GZf0vaJU2YE92z4P4GaVgf1fLcu+mOthyLC8kmjQ/D8zpdSmboLbDWo+bsw1TzLo98aarVJ"
            + "W24pVkhKXE7XisNFJC9u2q5yOZP0Nucy2W6jZ+KUGcGatZ0AgCWL2xMNUPwIrVnbickTL8SSxe015qDuv+T39YxAnbwuG0GUmcSZ"
            + "hc01calB+TEx7g8tqjyMDVXXqFwZ2v0vHLHKp21yPkaaR3kIUzU+0DQPS57bvh1AxVDi9qtEpTdl57M/KS1Z3F7Xz2eyPSqtDjpG"
            + "qqM3bL8JcreDjK05TpwyIzA91pUGtVzSGHxaLeJcNuVBCCGEEEIIIYQQQgghhBBCCCGEEEIIIYQQQgghhBBCCCGEEEIIIYSQdCS+"
            + "0EFdvTHqJRC66WzwQYNPWnzQQAipJ/ZtU/K7G6X1tOveRSjSKWtuO3nHpQ8afNLigwZCSDiDonakXZOlta3Nem1ynzT4pMUHDYSQ"
            + "aIzeh3rpoEGAsrwrUKmoYulb1ysn+qjBJy0+aCCEVNA2VHlp27Aoqbo/w4rrgwaftPiggRDSR2iT39USrGmamD5o8EmLDxqIWyZO"
            + "mRGo1yJs20DBl/JIo0M7Qm2/8ev4j2c/AwDY+PLimn0LJ6wFAHx8yi/Qed/f6J7SGB80EDeIm1NduE/d1l91TJwyIyjPnVszqCgP"
            + "JLYNsAFEX8ojrQ5tQ/2PZz+DkVcfwf5Hhobur+z7DIDFZt/AAB80kPT0l8qjngswM2HRJdO7+msgby9qyWRXPzC+lEfeOvrtqqfE"
            + "b3wxExc6lO4Y0/SR5G2qrn5gfCmPInRoG+rGlxfj9juBjS9X/hYjyE+dOFG3Lyt80BCFrKUofNCQhC9m4osOlYUT1jrptgrr79P5"
            + "DnE/MEXgqjzy0hFqqOqa1irKZPFIlLW1jfBBg09afNBA9LEdSEnbbSXyDbtPWtvaqssgRz0IEkdrWxt2PvuTVLpMcd2Nl7UOqya/"
            + "DxGQDxoEPmjxQYMg6qZVK6y6xrm8P63x62pwoUP+sRMR7WenTQtNO2rUqFjdt995Fza+3Nfa6IpNXYuuKfZS7Vt0NYNE4Et5FKFD"
            + "21AnT7xQK12WE8h90CDwQYsPGgSygUXdtCpx0falc+caD07ZaHClI6TyWiMqbdsDD2j/qMimuG/fvsT0srGa/NDpUnR5FKUj1FDV"
            + "XyzdiivSigosfhXk/ZYdys402EQ9LI94XdJ5C8EXDa7yz7O1EdE1ULdNmMmtmuf1pTzy1pEYoZpUXPkYpQLLGHfwO9aQaoCB5dGH"
            + "66ai4KkTJ7Sb/FlpMNXhmjT5JjVfGxFf+v6TdNQZqosbNG0T0wcNPmnxQYNKkiYb0wfy6Z7IEtvvLbD9/uqgZVodKk/tfKmuK0CH"
            + "osqjKB2xEaqtCDka6iqXayIi02koLjTIpJkGM5DLQ3eCtOuKbKPDlQaTyiwMLU3+z/ealg+RWFp8KY+8deQysV81kbxJa2JZ6yk6"
            + "f93y0En3/M6XMo9Oi75+cezbt69a+eQoXq6QE6fMCD47bRqe2749k1F2gWoEtv3wtsa289mflHY++xPoloN6vDhOTPdKc73zui6x"
            + "hmpbOVw221xpcGGqLI/aQa2oH4a031en8sTpSGPq8jkaNVoUrZE4/Vm3JAYqdYaq9sXIlSPqIkRVIPkXwURUFhp6/zT+xWF51GvI"
            + "MrpOMjFdHXmYus8k6TcpHxdlIe5Tm37YRiL2SSl1u2lhyBfB8linGmyOz0pLI5ZHlAaX6FRcX3TooGskrgynq1yONcAU938qlixu"
            + "D93+3PbtscdlZcR5XxdCCCGEEEIIIYQQQgghhBBCCCGEEEIIIYQQQgghhBBCCCGEEEIIIYQQQgghhBBCCCGEEEIIIYQQMhCYOGVG"
            + "oC7vEbZtoOgghAwsnK16OnHKjKA8dy6eOnEC6F3sTawaeOmgQWjLaZVKX3SE6QJql5PQXZqZENIYRFZk08qus+SqzWJfvuhIg2zy"
            + "6lK2lw4ahLYHHqCpEtIPCI1QFVNKjOh01682XbrZFx0u6I2YIdYZl7f7vM48IUSfQVlnsHDCWrTf+PWss/FWh4nJs4+XkMZGuw/V"
            + "trKPvPoI9j/yGQCLbQ73VgchhKjE9qGKyKqrXMZnp00LTTdq1CitjC4dVAmGTfsLfdGRpDFsuxqZqmt7y/vz7tclhLjHSZ9kEmlN"
            + "zBcdqibxOY3Jd5XLKM+dy4EpQvoBkU1+VyYG9A3I2OCLDoEwUheauspl/OrN1zH9z7+Fc879ZOrzEUKKxdk81CR8adKm0eHS3IWZ"
            + "EkL6D4mGOnnihakyeH7nS6mO90VHlJma6hI6WtvaaKqE9DMiDbU3igsAezN7fudLqSPTonToPFBgo0c9RgxU+RC9E0LSETmx/7PT"
            + "puG57dtx66I/rqvo6si7MIOo7S7Yt29f3VNGYfkL3Wo6G7KecD954oWYPPFCEbVyYj8hDU5ufaiNijBVoGLeskG76s7wpX+ZEJIO"
            + "54YqmrTqnMtGQ3Q19D4qmlk+NFNC+g+Rhvrc9u2xB0YZ55LF7Q5kJaNr3GkMXu6/zQqaKSH9h/8PLw3w38mAIXYAAAAASUVORK5C"
            + "YII=";
    }
}

// =====================================================================
//  Engine.cs  -  ORTAK SAHNE MOTORU, C# portu (Windows)
//
//  kaynak/scene.js'in BIREBIR karsiligidir. Birini degistirirsen digerini
//  de degistir ve kaynak/test/parity.sh ile karsilastir: ayni tohum ve
//  ayni tiklamalarla her tick ayni ozet satirini uretmeliler.
//
//  C# 5 (Windows PowerShell 5.1 Add-Type / csc.exe):  $"..", ?. ,
//  nameof, => uyeleri, otomatik ozellik ilk degerleri YOK. Dosya ASCII.
//
//  Neden C#: ayni motor PowerShell'de tick basina ~2.5-5 ms suruyordu
//  (yorumlanan dil + hashtable); burada mikrosaniyeler.
// =====================================================================

namespace TaskbarKedileri
{
    public sealed class DrawItem
    {
        public string K;
        public int X;
        public int Y;
        public bool F;
        public string Id;
        public DrawItem(string k, int x, int y, bool f, string id) { K = k; X = x; Y = y; F = f; Id = id; }
    }

    internal sealed class AnimDef
    {
        public string[] F;
        public int Hold;
        public int[] Bob;
        public AnimDef(int hold, int[] bob, params string[] f) { Hold = hold; Bob = bob; F = f; }
    }

    internal sealed class SceneDef
    {
        public int D0, D1;
        public bool Follow;
        public double Sun;
        public bool FlipDogis;
        public int DogX;
        public string DogA;
        public int[] CatX;
        public string[] CatA;
    }

    internal sealed class Actor
    {
        public string Name;
        public double X, Tx;
        public string Anim, NextAnim;
        public int Fi, Fh;
        public bool Flip, NextFlip;
        public int Y;
        public string Ov = "";
        public int OvT;
        public Actor(string name, double x, string anim) { Name = name; X = x; Tx = x; Anim = anim; NextAnim = anim; }
    }

    internal sealed class Fx
    {
        public string Kind;
        public double X, Y;
        public int Life;
        public string Own;
        public Fx(string kind, double x, double y, int life, string own) { Kind = kind; X = x; Y = y; Life = life; Own = own; }
    }

    public sealed class Engine
    {
        public const int STAGE_W = 200;
        public const int TICK = 80;
        public const int HEADROOM = 34;
        const int SUN_TOP = 0;
        const int SUN_CX = 16;
        const int DECOR_W = 37;
        const int DECOR_MARGIN = 6;
        const int FLOWER_DX = 19;

        // ---- tohumlu rastgele sayi (Park-Miller MINSTD) -------------------
        long _rng = 1;
        public void Seed(double s) { _rng = (long)(Math.Floor(Math.Abs(s)) % 2147483646) + 1; }
        double Rnd() { _rng = (_rng * 48271) % 2147483647; return (double)(_rng - 1) / 2147483646.0; }
        int RandInt(int a, int b) { return a + (int)Math.Floor(Rnd() * (b - a + 1)); }
        int[] Shuffle3()
        {
            int[] p = { 0, 1, 2 };
            for (int i = 2; i > 0; i--)
            {
                int j = (int)Math.Floor(Rnd() * (i + 1));
                int t = p[i]; p[i] = p[j]; p[j] = t;
            }
            return p;
        }

        // ---- animasyonlar ---------------------------------------------------
        static readonly Dictionary<string, AnimDef> ANIM = new Dictionary<string, AnimDef> {
            { "walk",   new AnimDef(2, null, "walk_1", "walk_2", "walk_3", "walk_4") },
            { "stand",  new AnimDef(8, null, "stand") },
            { "sit",    new AnimDef(8, null, "sit_a", "sit_a", "sit_a", "sit_blink") },
            { "sitwag", new AnimDef(6, null, "sit_a", "sit_b") },
            { "lookup", new AnimDef(8, null, "lookup", "lookup", "lookup", "sit_blink") },
            { "jump",   new AnimDef(2, null, "jump_1", "jump_2", "jump_3", "jump_2", "jump_1") },
            { "sleep",  new AnimDef(14, new int[] { 0, -1 }, "sleep_a", "sleep_b") },
            { "yawn",   new AnimDef(5, null, "sleep_a", "yawn", "yawn", "stretch", "stretch", "sleep_a") },
            { "rub",    new AnimDef(5, null, "rub_a", "rub_b") },
            { "happy",  new AnimDef(5, null, "sit_happy", "sit_b") },
        };
        static readonly Dictionary<string, AnimDef> HANIM = new Dictionary<string, AnimDef> {
            { "hwalk",  new AnimDef(3, null, "dogis_walk_1", "dogis_walk_2", "dogis_walk_3", "dogis_walk_4") },
            { "hstand", new AnimDef(10, null, "dogis_stand") },
            { "hwave",  new AnimDef(3, null, "dogis_wave_1", "dogis_wave_2", "dogis_wave_3", "dogis_wave_2") },
            { "hpet",   new AnimDef(6, null, "dogis_crouch_1", "dogis_crouch_2") },
            { "hjoy",   new AnimDef(4, null, "dogis_pet_1", "dogis_pet_2") },
            { "hangry", new AnimDef(5, null, "dogis_angry_1", "dogis_angry_2") },
        };

        // ---- sahneler ---------------------------------------------------------
        static SceneDef Sc(int d0, int d1, bool follow, double sun, bool flip, int dx, string da,
                           int c0, string a0, int c1, string a1, int c2, string a2)
        {
            SceneDef s = new SceneDef();
            s.D0 = d0; s.D1 = d1; s.Follow = follow; s.Sun = sun; s.FlipDogis = flip;
            s.DogX = dx; s.DogA = da;
            s.CatX = new int[] { c0, c1, c2 };
            s.CatA = new string[] { a0, a1, a2 };
            return s;
        }
        static readonly Dictionary<string, SceneDef> SCENES = new Dictionary<string, SceneDef> {
            { "parade", Sc(180, 300, true,  0.6, false, 150, "hwalk",  108, "walk", 68, "walk",   28, "walk") },
            { "play",   Sc(200, 320, false, 0.1, true,  152, "hwave",  112, "jump", 74, "lookup", 34, "sit") },
            { "pet",    Sc(200, 320, false, 0.1, true,  146, "hpet",   116, "rub",  76, "happy",  36, "sitwag") },
            { "nap",    Sc(250, 400, false, 0.1, false, 150, "hstand", 104, "sleep", 66, "yawn",  26, "sleep") },
        };
        public static readonly string[] ORDER = { "parade", "play", "pet", "nap" };

        static readonly string[] SNIFF_K = { "giraffe_lean", "giraffe_sniff_1", "giraffe_sniff_2",
                                             "giraffe_sniff_1", "giraffe_sniff_2", "giraffe_sniff_1", "giraffe_lean" };
        static readonly int[] SNIFF_T = { 4, 6, 6, 6, 6, 5, 4 };
        static readonly string[] FLWIG = { "flower_1", "flower_2", "flower_1", "flower_3" };

        // ---- durum ------------------------------------------------------------
        public string Scene = "parade";
        int _t, _clock, _dur = 200;
        string _phase = "run";
        int _screenW;
        double _groupX, _lead = 60;
        double _sunX; int _sunDir = 1;
        int _pets, _need = 3, _last = -1000;
        int _dcWait, _dcSeq = -1, _dcSeqT, _dcBlink, _dcBlinkWait;
        readonly Actor[] _actors;
        List<Fx> _fx = new List<Fx>();
        List<DrawItem> _draw = new List<DrawItem>();

        public List<DrawItem> Draw { get { return _draw; } }
        public int ScreenW { get { return _screenW; } }
        public int Clock { get { return _clock; } }
        public int DecorX { get { return _screenW - DECOR_MARGIN - DECOR_W; } }

        public Engine(int screenW, double seed)
        {
            Seed(seed);
            _screenW = screenW;
            _actors = new Actor[] { new Actor("dogis", 150, "hwalk"), new Actor("tarcin", 108, "walk"),
                                    new Actor("maya", 68, "walk"), new Actor("zilli", 28, "walk") };
            _groupX = Math.Floor(screenW / 2.0 - STAGE_W / 2.0);
            _sunX = _groupX + STAGE_W / 2.0 + 60;
            _need = RandInt(2, 3);
            _dcWait = RandInt(150, 300);
            _dcBlinkWait = RandInt(40, 120);
            ClampWorld();
            BuildDraw();
        }

        // ---- yerlesim -------------------------------------------------------------
        double GroupMax() { return Math.Max(8.0, (double)(DecorX - 8 - STAGE_W)); }
        double SunMin() { return 24; }
        double SunMax() { return Math.Max(25.0, (double)(DecorX - 24)); }

        void ClampWorld()
        {
            if (_groupX > GroupMax()) _groupX = GroupMax();
            if (_groupX < 8) _groupX = 8;
            if (_sunX > SunMax()) _sunX = SunMax();
            if (_sunX < SunMin()) _sunX = SunMin();
        }
        public void SetScreen(int w) { _screenW = w; ClampWorld(); BuildDraw(); }

        double FollowTarget()
        {
            double t = _sunX - STAGE_W / 2.0 - _lead;
            if (t > GroupMax()) t = GroupMax();
            if (t < 8) t = 8;
            return t;
        }

        // ---- sahne gecisi ------------------------------------------------------------
        public void ApplyScene(string name)
        {
            SceneDef s = SCENES[name];
            Scene = name; _t = 0; _phase = "move";
            _dur = s.D0 + (int)Math.Floor(Rnd() * (s.D1 - s.D0));
            _actors[0].Tx = s.DogX; _actors[0].NextAnim = s.DogA;
            _actors[0].NextFlip = s.FlipDogis;
            int[] perm = Shuffle3();
            for (int i = 0; i < 3; i++)
            {
                int slot = perm[i];
                _actors[i + 1].Tx = s.CatX[slot];
                _actors[i + 1].NextAnim = s.CatA[slot];
                _actors[i + 1].NextFlip = false;
            }
        }

        string PickNextScene()
        {
            if (Scene != "parade" && Math.Abs(FollowTarget() - _groupX) > 40) return "parade";
            List<string> others = new List<string>();
            foreach (string n in ORDER) if (n != Scene) others.Add(n);
            return others[(int)Math.Floor(Rnd() * others.Count)];
        }

        // ---- etkilesim -------------------------------------------------------------------
        static void SetOv(Actor a, string anim, int ticks) { a.Ov = anim; a.OvT = ticks; a.Fi = 0; a.Fh = 0; }

        Actor FindActor(string id)
        {
            foreach (Actor a in _actors) if (a.Name == id) return a;
            return null;
        }

        /// <summary>Donus: "joy" | "angry" | "jump" | ""</summary>
        public string Poke(string id)
        {
            Actor a = FindActor(id);
            if (a == null) return "";
            if (id == "dogis")
            {
                if (a.Ov == "hangry")
                {
                    if (a.OvT < 25) a.OvT = 25;
                    return "angry";
                }
                if (_clock - _last > 150) _pets = 0;
                _pets++; _last = _clock;
                if (_pets >= _need)
                {
                    SetOv(a, "hangry", 64);
                    _pets = 0; _need = RandInt(2, 3);
                    _fx.RemoveAll(delegate (Fx f) { return f.Own == "dogis"; });   // kalpler soner
                    return "angry";
                }
                SetOv(a, "hjoy", 24);
                _fx.Add(new Fx("fx_heart", _groupX + a.X, -6, 24, "dogis"));
                return "joy";
            }
            SetOv(a, "jump", 26);
            _fx.Add(new Fx("fx_heart", _groupX + a.X + 6, -4, 24, null));
            return "jump";
        }

        /// <summary>Sprite pikseli koordinatina tiklama. hit(kare, lx, ly) -> opak mi?</summary>
        public string ClickAt(int sx, int sy, int cw, int ch, Func<string, int, int, bool> hit)
        {
            for (int i = _draw.Count - 1; i >= 0; i--)
            {
                DrawItem d = _draw[i];
                if (string.IsNullOrEmpty(d.Id)) continue;
                int lx = sx - d.X, ly = sy - d.Y;
                if (lx < 0 || ly < 0 || lx >= cw || ly >= ch) continue;
                if (hit(d.K, d.F ? cw - 1 - lx : lx, ly)) { Poke(d.Id); return d.Id; }
            }
            return "";
        }

        // ---- kare adi ---------------------------------------------------------------------
        static AnimDef SetOf(Actor a)
        {
            string an = a.Ov.Length > 0 ? a.Ov : a.Anim;
            return a.Name == "dogis" ? HANIM[an] : ANIM[an];
        }
        static string FrameName(Actor a)
        {
            AnimDef set = SetOf(a);
            string f = set.F[a.Fi % set.F.Length];
            return a.Name == "dogis" ? f : a.Name + "_" + f;
        }

        // ---- tick -------------------------------------------------------------------------
        public void Step()
        {
            _t++; _clock++;
            SceneDef s = SCENES[Scene];
            Actor dog = _actors[0];
            bool hold = dog.Ov == "hangry";

            // gunes suzulur, kenarlarda doner
            _sunX += s.Sun * _sunDir;
            if (_sunX > SunMax()) { _sunX = SunMax(); _sunDir = -1; }
            if (_sunX < SunMin()) { _sunX = SunMin(); _sunDir = 1; }
            double wantLead = 60 * _sunDir;
            if (_lead < wantLead) _lead = Math.Min(wantLead, _lead + 0.5);
            else if (_lead > wantLead) _lead = Math.Max(wantLead, _lead - 0.5);

            if (_phase == "move")
            {
                bool moving = false;
                foreach (Actor a in _actors)
                {
                    if (a.Ov == "hangry") { moving = true; continue; }
                    double d = a.Tx - a.X;
                    if (Math.Abs(d) > 1.5)
                    {
                        a.X += Math.Sign(d) * 2; a.Flip = d < 0;
                        a.Anim = a.Name == "dogis" ? "hwalk" : "walk";
                        moving = true;
                    }
                    else
                    {
                        a.X = a.Tx; a.Anim = a.NextAnim; a.Flip = a.NextFlip;
                    }
                }
                if (!moving) { _phase = "run"; _t = 0; }
            }
            else
            {
                if (s.Follow)
                {
                    double v = 0;
                    if (!hold)
                    {
                        v = (FollowTarget() - _groupX) * 0.05;
                        if (v > 2) v = 2;
                        if (v < -2) v = -2;
                        if (Math.Abs(v) < 0.15) v = 0;
                    }
                    _groupX += v;
                    ClampWorld();
                    bool walking = v != 0;
                    bool faceLeft = walking ? v < 0 : _sunX < _groupX + STAGE_W / 2.0;
                    foreach (Actor a in _actors)
                    {
                        if (a.Name == "dogis") a.Anim = walking ? "hwalk" : "hstand";
                        else a.Anim = walking ? "walk" : "stand";
                        a.Flip = faceLeft;
                    }
                }
                if (_t > _dur) ApplyScene(PickNextScene());
            }

            // kareler
            foreach (Actor a in _actors)
            {
                if (a.OvT > 0)
                {
                    a.OvT--;
                    if (a.OvT == 0) { a.Ov = ""; a.Fi = 0; a.Fh = 0; }
                }
                string an = a.Ov.Length > 0 ? a.Ov : a.Anim;
                AnimDef set = a.Name == "dogis" ? HANIM[an] : ANIM[an];
                a.Fh++;
                if (a.Fh >= set.Hold) { a.Fh = 0; a.Fi = (a.Fi + 1) % set.F.Length; }
                if (an == "jump")
                {
                    string f = a.Fi < set.F.Length ? set.F[a.Fi] : null;   // JS: undefined -> 0
                    a.Y = f == "jump_2" ? -5 : (f == "jump_3" ? -3 : 0);
                }
                else if (set.Bob != null)
                {
                    a.Y = set.Bob[a.Fi % set.Bob.Length];
                }
                else
                {
                    a.Y = 0;
                }
            }

            // zurafa ve cicek
            if (_dcBlink > 0)
            {
                _dcBlink--;
            }
            else
            {
                _dcBlinkWait--;
                if (_dcBlinkWait <= 0) { _dcBlink = 3; _dcBlinkWait = RandInt(50, 140); }
            }
            if (_dcSeq < 0)
            {
                _dcWait--;
                if (_dcWait <= 0) { _dcSeq = 0; _dcSeqT = 0; }
            }
            else
            {
                _dcSeqT++;
                if (_dcSeqT >= SNIFF_T[_dcSeq])
                {
                    _dcSeqT = 0; _dcSeq++;
                    if (_dcSeq == 3) _fx.Add(new Fx("fx_heart_s", DecorX + 12, -6, 22, null));
                    if (_dcSeq >= SNIFF_K.Length) { _dcSeq = -1; _dcWait = RandInt(220, 480); }
                }
            }

            // sahne efektleri
            if (_phase == "run")
            {
                if (Scene == "pet" && _t % 22 == 0)
                {
                    Actor p = _actors[1];
                    foreach (Actor a in _actors) if (a.Anim == "rub") { p = a; break; }
                    string k = Rnd() < 0.5 ? "fx_heart" : "fx_heart_s";
                    _fx.Add(new Fx(k, _groupX + p.X + 4, -4, 26, null));
                }
                if (Scene == "nap" && _t % 16 == 0)
                {
                    List<Actor> sl = new List<Actor>();
                    foreach (Actor a in _actors) if (a.Anim == "sleep") sl.Add(a);
                    Actor p = sl.Count > 0 ? sl[(int)Math.Floor(Rnd() * sl.Count)] : _actors[1];
                    _fx.Add(new Fx("zzz", _groupX + p.X + 8, -2, 30, null));
                }
                if (Scene == "play" && _t % 30 == 0)
                    _fx.Add(new Fx("fx_spark", _groupX + _actors[0].X - 12, -14, 12, null));
            }
            List<Fx> keep = new List<Fx>(_fx.Count);
            foreach (Fx f in _fx)
            {
                f.Life--; f.Y -= 0.5;
                if (f.Life > 0) keep.Add(f);
            }
            _fx = keep;

            BuildDraw();
        }

        // ---- cizim listesi -------------------------------------------------------------------
        void BuildDraw()
        {
            List<DrawItem> o = new List<DrawItem>(16);
            // 1) gunes
            o.Add(new DrawItem("sun_" + (1 + (_clock / 2) % 4), (int)Math.Floor(_sunX) - SUN_CX, SUN_TOP, false, ""));
            // 2) zurafa + cicek (cicek once)
            int dx = DecorX;
            bool sniffing = _dcSeq >= 0;
            string fl = FLWIG[(_clock / (sniffing ? 4 : 12)) % 4];
            o.Add(new DrawItem(fl, dx + FLOWER_DX, HEADROOM, false, ""));
            string gf;
            if (sniffing) gf = SNIFF_K[_dcSeq];
            else if (_dcBlink > 0) gf = "giraffe_blink";
            else gf = (_clock / 14) % 2 == 1 ? "giraffe_idle_2" : "giraffe_idle_1";
            o.Add(new DrawItem(gf, dx, HEADROOM, false, ""));
            // 3) karakterler
            foreach (Actor a in _actors)
                o.Add(new DrawItem(FrameName(a), (int)Math.Floor(_groupX + a.X), HEADROOM + a.Y, a.Flip, a.Name));
            // 4) Dogis'in ofke isareti ve buhar
            Actor dog = _actors[0];
            if (dog.Ov == "hangry")
            {
                int bx = (int)Math.Floor(_groupX + dog.X), by = HEADROOM + dog.Y;
                o.Add(new DrawItem("fx_anger_" + (1 + (_clock / 4) % 2), bx + (dog.Flip ? 7 : 20), by - 29, false, ""));
                if (FrameName(dog) == "dogis_angry_2")
                    o.Add(new DrawItem("fx_huff", bx + (dog.Flip ? -5 : 5), by - 21, dog.Flip, ""));
            }
            // 5) ucan efektler
            foreach (Fx f in _fx)
            {
                string k = f.Kind;
                if (k == "zzz") k = "fx_zzz_" + Math.Max(1, Math.Min(3, 3 - (int)Math.Floor((30 - f.Life) / 10.0)));
                o.Add(new DrawItem(k, (int)Math.Floor(f.X), (int)Math.Floor(HEADROOM + f.Y - 14), false, ""));
            }
            _draw = o;
        }

        // ---- karsilastirma testi icin tek satirlik ozet -------------------------------------
        static string Fl(double v) { return ((long)Math.Floor(v * 1000)).ToString(CultureInfo.InvariantCulture); }
        public string Digest()
        {
            CultureInfo ci = CultureInfo.InvariantCulture;
            StringBuilder sb = new StringBuilder();
            sb.Append(_clock.ToString(ci)).Append('|').Append(Scene).Append('|').Append(_phase).Append('|')
              .Append(Fl(_groupX)).Append('|').Append(Fl(_sunX)).Append('|').Append(_sunDir.ToString(ci)).Append('|')
              .Append(Fl(_lead)).Append('|').Append(_pets.ToString(ci)).Append('/').Append(_need.ToString(ci))
              .Append('|').Append(_fx.Count.ToString(ci));
            foreach (DrawItem d in _draw)
                sb.Append('|').Append(d.K).Append(',').Append(d.X.ToString(ci)).Append(',').Append(d.Y.ToString(ci))
                  .Append(',').Append(d.F ? '1' : '0').Append(',').Append(d.Id);
            return sb.ToString();
        }
    }
}

// =====================================================================
//  KediWidget.cs  -  Windows cizici + zamanlayici + tiklama (C# 5, ASCII)
//
//  PowerShell yalnizca kurulumu yapar (pencere, menu); her tick'te calisan
//  her sey burada, derlenmis kodda:
//    - Engine.Step()                      (tick basina ~mikrosaniyeler)
//    - yalnizca DEGISEN sprite'larin dikdortgenleri yeniden cizilir
//      (onceden her tick 1920x134 pencerenin tamami temizlenip ciziliyordu)
//    - pencere tamamen ortuluyken (tam ekran uygulama, ekran kilidi, her
//      sprite'in ustunde bir pencere) motor ve cizim DURUR; 320 ms'de bir
//      sadece "gorunur oldum mu?" diye bakilir
//    - surec "verimlilik" moduna alinir: BelowNormal oncelik + EcoQoS
//      (Win10 1709+/Win11). Kullanicinin uygulamalari her zaman once gelir.
// =====================================================================

namespace TaskbarKedileri
{
    internal static class KediNative
    {
        [StructLayout(LayoutKind.Sequential)]
        public struct POINT { public int X; public int Y; public POINT(int x, int y) { X = x; Y = y; } }

        [StructLayout(LayoutKind.Sequential)]
        public struct POWER_THROTTLING { public uint Version; public uint ControlMask; public uint StateMask; }

        [DllImport("user32.dll")] public static extern IntPtr WindowFromPoint(POINT p);
        [DllImport("user32.dll")] public static extern IntPtr GetAncestor(IntPtr hwnd, uint flags);
        [DllImport("user32.dll", CharSet = CharSet.Unicode)]
        public static extern int GetClassName(IntPtr hWnd, StringBuilder name, int max);
        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern bool SetProcessInformation(IntPtr process, int infoClass, ref POWER_THROTTLING info, int size);
        [DllImport("kernel32.dll")] public static extern IntPtr GetCurrentProcess();

        public const uint GA_ROOT = 2;
        public const int ProcessPowerThrottling = 4;
    }

    public sealed class KediWidget : IDisposable
    {
        const int CoveredCheckEvery = 4;      // gorunurken: 4 tick'te bir (~320 ms)
        const int CoveredInterval = 320;      // ortuluyken zamanlayici araligi (ms)

        readonly Control _form;
        readonly Bitmap _sheet, _sheetF;      // 32bppPArgb: GDI+'in en hizli kaynak bicimi
        readonly bool[] _opaque;              // tiklama testi icin alfa maskesi
        readonly int _sheetW, _sheetH, _cw, _ch;
        readonly Dictionary<string, Point> _frames = new Dictionary<string, Point>();
        readonly Dictionary<string, Bitmap> _scaledCache = new Dictionary<string, Bitmap>();
        readonly System.Windows.Forms.Timer _timer;
        readonly Random _rand = new Random();
        readonly StringBuilder _cls = new StringBuilder(64);

        Engine _eng;
        int _scale = 2;
        bool _paused, _covered, _disposed;
        int _sinceCheck;

        // istatistik (CATBAR_PERF=1 iken PowerShell log'a yazar)
        long _ticks, _coveredTicks, _paints, _rectsPainted;
        readonly Stopwatch _stepWatch = new Stopwatch(), _paintWatch = new Stopwatch(), _tickWatch = new Stopwatch();

        public KediWidget(Control form, Image sheet, IDictionary frames, int cellW, int cellH)
        {
            _form = form;
            _cw = cellW; _ch = cellH;
            _sheetW = sheet.Width; _sheetH = sheet.Height;
            _sheet = new Bitmap(_sheetW, _sheetH, PixelFormat.Format32bppPArgb);
            using (Graphics g = Graphics.FromImage(_sheet))
            {
                g.CompositingMode = CompositingMode.SourceCopy;
                g.DrawImage(sheet, new Rectangle(0, 0, _sheetW, _sheetH), 0, 0, _sheetW, _sheetH, GraphicsUnit.Pixel);
            }
            _sheetF = (Bitmap)_sheet.Clone();
            _sheetF.RotateFlip(RotateFlipType.RotateNoneFlipX);

            _opaque = new bool[_sheetW * _sheetH];
            using (Bitmap argb = new Bitmap(sheet))
            {
                BitmapData bd = argb.LockBits(new Rectangle(0, 0, _sheetW, _sheetH), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
                try
                {
                    byte[] row = new byte[_sheetW * 4];
                    for (int y = 0; y < _sheetH; y++)
                    {
                        Marshal.Copy(new IntPtr(bd.Scan0.ToInt64() + (long)y * bd.Stride), row, 0, row.Length);
                        for (int x = 0; x < _sheetW; x++) _opaque[y * _sheetW + x] = row[x * 4 + 3] > 0;
                    }
                }
                finally { argb.UnlockBits(bd); }
            }

            foreach (DictionaryEntry de in frames)
            {
                object[] xy = de.Value as object[];
                if (xy == null || xy.Length < 2) continue;
                _frames[(string)de.Key] = new Point(Convert.ToInt32(xy[0]), Convert.ToInt32(xy[1]));
            }

            _timer = new System.Windows.Forms.Timer();
            _timer.Interval = Engine.TICK;
            _timer.Tick += OnTick;
            _form.Paint += OnPaint;
            _form.MouseDown += OnMouseDown;
        }

        // ============================================================ public API (PowerShell)

        /// <summary>Ilk cagrida motoru kurar ve zamanlayiciyi baslatir.</summary>
        public void SetLayout(int scale, int screenW)
        {
            if (Math.Max(1, scale) != _scale) ClearScaled();
            _scale = Math.Max(1, scale);
            if (_eng == null)
            {
                _eng = new Engine(screenW, (double)(Environment.TickCount & 0x7fffffff));
                _timer.Start();
            }
            else _eng.SetScreen(screenW);
            InvalidateAll();
        }

        public bool Paused { get { return _paused; } set { _paused = value; } }

        /// <summary>Testler icin: motorun kendisi.</summary>
        public Engine Engine { get { return _eng; } }

        public void NextScene()
        {
            if (_eng == null) return;
            List<string> others = new List<string>();
            foreach (string n in Engine.ORDER) if (n != _eng.Scene) others.Add(n);
            _eng.ApplyScene(others[_rand.Next(others.Count)]);
        }

        public string Stats()
        {
            double avgStep = _ticks - _coveredTicks > 0 ? _stepWatch.Elapsed.TotalMilliseconds / (_ticks - _coveredTicks) : 0;
            double avgPaint = _paints > 0 ? _paintWatch.Elapsed.TotalMilliseconds / _paints : 0;
            string s = string.Format(System.Globalization.CultureInfo.InvariantCulture,
                "tick={0} ortulu={1} step={2:F4}ms tick_toplam={7:F3}ms/tick boyama={3} ({4:F3}ms/boyama, {5} dikdortgen) olcek={6}",
                _ticks, _coveredTicks, avgStep, _paints, avgPaint, _rectsPainted, _scale,
                _ticks > 0 ? _tickWatch.Elapsed.TotalMilliseconds / _ticks : 0);
            DesktopForm df = _form as DesktopForm;
            if (df != null) s += " | " + df.PerfStats();
            return s;
        }

        /// <summary>BelowNormal oncelik + EcoQoS (Win11 "verimlilik modu"nun CPU tarafi). Hata sessizce yutulur.</summary>
        public static string EnableEfficiencyMode()
        {
            string r = "";
            try { Process.GetCurrentProcess().PriorityClass = ProcessPriorityClass.BelowNormal; r += "oncelik=BelowNormal"; }
            catch (Exception ex) { r += "oncelik hata: " + ex.Message; }
            try
            {
                KediNative.POWER_THROTTLING s = new KediNative.POWER_THROTTLING();
                s.Version = 1; s.ControlMask = 1; s.StateMask = 1;   // EXECUTION_SPEED -> EcoQoS
                bool ok = KediNative.SetProcessInformation(KediNative.GetCurrentProcess(), KediNative.ProcessPowerThrottling,
                                                           ref s, Marshal.SizeOf(typeof(KediNative.POWER_THROTTLING)));
                r += ok ? " EcoQoS=acik" : " EcoQoS=desteklenmiyor";
            }
            catch (Exception) { r += " EcoQoS=yok"; }   // eski Windows: fonksiyon yok
            return r;
        }

        // ============================================================ tick

        void OnTick(object sender, EventArgs e)
        {
            if (_disposed || _eng == null) return;
            _ticks++;
            _tickWatch.Start();
            try { TickBody(); }
            finally { _tickWatch.Stop(); }
        }

        void TickBody()
        {
            if (_covered || ++_sinceCheck >= CoveredCheckEvery)
            {
                _sinceCheck = 0;
                bool cov = !AnyItemVisible();
                if (cov != _covered)
                {
                    _covered = cov;
                    _timer.Interval = cov ? CoveredInterval : Engine.TICK;
                }
            }
            if (_covered) { _coveredTicks++; return; }   // kimse gormuyor: ne motor ne cizim

            if (!_paused)
            {
                _stepWatch.Start();
                _eng.Step();
                _stepWatch.Stop();
            }
            InvalidateChanges();
        }

        string KeyOf(DrawItem d) { return d.K + "|" + d.X + "|" + d.Y + (d.F ? "|f" : "|"); }

        Rectangle RectOf(DrawItem d) { return new Rectangle(d.X * _scale, d.Y * _scale, _cw * _scale, _ch * _scale); }

        /// <summary>Ekranda su an duranlar (anahtar -> alan). Bir sonraki karede farklar bulunur.</summary>
        Dictionary<string, Rectangle> _shown = new Dictionary<string, Rectangle>();

        /// <summary>Onceki kareyle farkli olan sprite'larin alanlarini (eski + yeni yer) yeniden boyatir.</summary>
        void InvalidateChanges()
        {
            Dictionary<string, Rectangle> now = Snapshot();
            List<Rectangle> dirty = new List<Rectangle>();
            foreach (KeyValuePair<string, Rectangle> kv in now)
                if (!_shown.ContainsKey(kv.Key)) dirty.Add(kv.Value);          // yeni / degisen kare
            foreach (KeyValuePair<string, Rectangle> kv in _shown)
                if (!now.ContainsKey(kv.Key)) dirty.Add(kv.Value);             // eski yeri silinmeli
            _shown = now;
            PaintRects(Merge(dirty));
        }

        Dictionary<string, Rectangle> Snapshot()
        {
            Dictionary<string, Rectangle> d = new Dictionary<string, Rectangle>();
            if (_eng == null) return d;
            int n = 0;
            foreach (DrawItem it in _eng.Draw)
            {
                string k = KeyOf(it);
                if (d.ContainsKey(k)) k = k + "#" + (n++);   // ayni yerde iki ayni kare (cok nadir)
                d[k] = RectOf(it);
            }
            return d;
        }

        static List<Rectangle> Merge(List<Rectangle> rs)
        {
            List<Rectangle> o = new List<Rectangle>(rs);
            bool merged = true;
            while (merged)
            {
                merged = false;
                for (int a = 0; a < o.Count && !merged; a++)
                    for (int b = a + 1; b < o.Count; b++)
                    {
                        Rectangle ra = o[a], rb = o[b];
                        Rectangle grown = Rectangle.Inflate(ra, 4, 4);
                        if (grown.IntersectsWith(rb))
                        {
                            o[a] = Rectangle.Union(ra, rb);
                            o.RemoveAt(b);
                            merged = true;
                            break;
                        }
                    }
            }
            return o;
        }

        void PaintRects(List<Rectangle> rs)
        {
            if (rs.Count == 0 || !_form.IsHandleCreated || !_form.Visible) return;
            Rectangle client = _form.ClientRectangle;
            List<Rectangle> parts = new List<Rectangle>(rs.Count);
            foreach (Rectangle r0 in rs)
            {
                Rectangle r = Rectangle.Intersect(r0, client);
                if (r.Width > 0 && r.Height > 0) parts.Add(r);
            }
            if (parts.Count == 0) return;
            DesktopForm df = _form as DesktopForm;
            if (df != null)
            {
                // tek WM_PAINT: tum kucuk alanlar birlikte, ama yalnizca onlar yeniden olusturulur
                df.DirtyHint = parts;
                foreach (Rectangle r in parts) _form.Invalidate(r);
                _form.Update();
                df.DirtyHint = null;
                _rectsPainted += parts.Count;
                return;
            }
            foreach (Rectangle r in parts)
            {
                _form.Invalidate(r);
                _form.Update();          // siradan Form: her dikdortgen ayri ve kucuk bir WM_PAINT
                _rectsPainted++;
            }
        }

        void InvalidateAll()
        {
            _shown = Snapshot();
            if (_form.IsHandleCreated) _form.Invalidate();
        }

        // ============================================================ boyama

        void OnPaint(object sender, PaintEventArgs e)
        {
            if (_eng == null) return;
            _paintWatch.Start();
            Graphics g = e.Graphics;
            g.InterpolationMode = InterpolationMode.NearestNeighbor;
            g.PixelOffsetMode = PixelOffsetMode.None;
            g.SmoothingMode = SmoothingMode.None;
            g.CompositingQuality = CompositingQuality.HighSpeed;
            g.CompositingMode = CompositingMode.SourceOver;
            Rectangle clip = e.ClipRectangle;
            foreach (DrawItem d in _eng.Draw)
            {
                Rectangle dst = RectOf(d);
                if (!dst.IntersectsWith(clip)) continue;
                Bitmap b = Scaled(d.K, d.F);
                if (b != null) g.DrawImage(b, dst, 0, 0, dst.Width, dst.Height, GraphicsUnit.Pixel);   // olceklemesiz kopya
            }
            _paintWatch.Stop();
            _paints++;
        }

        /// <summary>Karenin bu olcekte onceden buyutulmus kopyasi (ilk kullanimda olusur).</summary>
        Bitmap Scaled(string k, bool flip)
        {
            string key = flip ? k + "|f" : k;
            Bitmap b;
            if (_scaledCache.TryGetValue(key, out b)) return b;
            Point p;
            if (!_frames.TryGetValue(k, out p)) return null;
            int w = _cw * _scale, h = _ch * _scale;
            b = new Bitmap(w, h, PixelFormat.Format32bppPArgb);
            using (Graphics g = Graphics.FromImage(b))
            {
                g.InterpolationMode = InterpolationMode.NearestNeighbor;
                g.PixelOffsetMode = PixelOffsetMode.Half;
                g.CompositingMode = CompositingMode.SourceCopy;
                Rectangle dst = new Rectangle(0, 0, w, h);
                if (flip) g.DrawImage(_sheetF, dst, _sheetW - p.X - _cw, p.Y, _cw, _ch, GraphicsUnit.Pixel);
                else g.DrawImage(_sheet, dst, p.X, p.Y, _cw, _ch, GraphicsUnit.Pixel);
            }
            _scaledCache[key] = b;
            return b;
        }

        void ClearScaled()
        {
            foreach (Bitmap b in _scaledCache.Values) b.Dispose();
            _scaledCache.Clear();
        }

        // ============================================================ tiklama

        bool Hit(string k, int lx, int ly)
        {
            Point p;
            if (!_frames.TryGetValue(k, out p)) return false;
            int x = p.X + lx, y = p.Y + ly;
            if (x < 0 || y < 0 || x >= _sheetW || y >= _sheetH) return false;
            return _opaque[y * _sheetW + x];
        }

        void OnMouseDown(object sender, MouseEventArgs e)
        {
            if (e.Button != MouseButtons.Left || _eng == null) return;
            int sx = (int)Math.Floor((double)e.X / _scale), sy = (int)Math.Floor((double)e.Y / _scale);
            _eng.ClickAt(sx, sy, _cw, _ch, Hit);   // kedi: zipla, Dogis: sevin / bik
            if (_covered) { _covered = false; _timer.Interval = Engine.TICK; }
        }

        // ============================================================ gorunurluk

        /// <summary>Herhangi bir sprite'in uzerinde masaustu (ya da biz) gorunuyor mu?</summary>
        bool AnyItemVisible()
        {
            try
            {
                if (!_form.IsHandleCreated || !_form.Visible) return false;
                Point o = _form.PointToScreen(Point.Empty);
                IntPtr me = _form.Handle;
                IntPtr myRoot = KediNative.GetAncestor(me, KediNative.GA_ROOT);
                foreach (DrawItem d in _eng.Draw)
                {
                    Rectangle r = RectOf(d);
                    int cx = o.X + r.X + r.Width / 2, y1 = o.Y + r.Y + r.Height * 2 / 3;
                    if (Shows(cx, y1, me, myRoot)) return true;
                    if (Shows(o.X + r.X + r.Width / 4, y1, me, myRoot)) return true;
                    if (Shows(o.X + r.X + r.Width * 3 / 4, y1, me, myRoot)) return true;
                    if (Shows(cx, o.Y + r.Y + r.Height / 3, me, myRoot)) return true;
                }
                return false;
            }
            catch (Exception) { return true; }   // emin degilsek calismaya devam
        }

        bool Shows(int x, int y, IntPtr me, IntPtr myRoot)
        {
            IntPtr h = KediNative.WindowFromPoint(new KediNative.POINT(x, y));
            if (h == IntPtr.Zero) return false;                 // ekran disi / kilit ekrani
            IntPtr root = KediNative.GetAncestor(h, KediNative.GA_ROOT);
            if (root == me || root == myRoot) return true;     // biz ya da bizi tasiyan masaustu
            _cls.Length = 0;
            KediNative.GetClassName(root, _cls, _cls.Capacity);
            string c = _cls.ToString();
            return c == "Progman" || c == "WorkerW";           // masaustu (ikonlar / duvar kagidi)
        }

        public void Dispose()
        {
            if (_disposed) return;
            _disposed = true;
            _timer.Stop();
            _timer.Dispose();
            _form.Paint -= OnPaint;
            _form.MouseDown -= OnMouseDown;
            ClearScaled();
            _sheet.Dispose();
            _sheetF.Dispose();
        }
    }
}

// =====================================================================
//  DesktopHost.cs  -  Taskbar Kedileri: "true desktop widget" window
//
//  Compiled at runtime by Windows PowerShell 5.1 Add-Type (legacy CodeDom
//  csc.exe of .NET Framework 4.x)  ->  C# 5 syntax ONLY:
//    no $"..", no ?. , no nameof, no => members, no auto-property
//    initialisers, no out var, no unsafe code.  Keep this file ASCII.
//
//  References: System.Windows.Forms, System.Drawing
//
//  Modes (DesktopForm.Mode):
//    "Desktop" - PRIMARY. The form is created as a WS_CHILD + WS_EX_LAYERED
//                window of the top-level window that hosts SHELLDLL_DefView
//                (Progman on Win11 24H2+ "raised desktop" and on a plain
//                Win10/11 desktop; a WorkerW on older trees after 0x052C).
//                It sits above the icon view, below every app window, and
//                rides along with the desktop during Show Desktop.
//    "Bottom"  - FALLBACK. Unowned top-level tool window (WS_EX_NOACTIVATE)
//                kept directly above the desktop host in the z-order; any
//                attempt to change its z-order is vetoed in
//                WM_WINDOWPOSCHANGING; a watchdog + WinEvent hook re-place
//                it (this is also what makes it visible during Show Desktop).
//
//  Click-through: transparent (TransparencyKey) pixels let clicks through
//  natively (layered colour-key hit testing) AND the form toggles
//  WS_EX_TRANSPARENT from a 30 ms cursor poll against its own back buffer,
//  so pass-through works even where native hit testing would not.
// =====================================================================

namespace TaskbarKedileri
{
    public enum DesktopModeRequest
    {
        Auto = 0,     // Desktop if possible, else Bottom
        Desktop = 1,  // same as Auto, but also clears an earlier hard failure
        Bottom = 2    // never reparent into Explorer
    }

    public class DesktopLogEventArgs : EventArgs
    {
        private readonly string _message;
        public DesktopLogEventArgs(string message) { _message = message; }
        public string Message { get { return _message; } }
    }

    // -----------------------------------------------------------------
    //  Win32
    // -----------------------------------------------------------------
    internal static class Native
    {
        public const int GWL_STYLE = -16;
        public const int GWL_EXSTYLE = -20;

        public const int WS_CHILD = 0x40000000;
        public const int WS_POPUP = unchecked((int)0x80000000);
        public const int WS_CLIPSIBLINGS = 0x04000000;
        public const int WS_CAPTION = 0x00C00000;
        public const int WS_SYSMENU = 0x00080000;
        public const int WS_THICKFRAME = 0x00040000;
        public const int WS_MINIMIZEBOX = 0x00020000;
        public const int WS_MAXIMIZEBOX = 0x00010000;

        public const int WS_EX_TOPMOST = 0x00000008;
        public const int WS_EX_TRANSPARENT = 0x00000020;
        public const int WS_EX_TOOLWINDOW = 0x00000080;
        public const int WS_EX_APPWINDOW = 0x00040000;
        public const int WS_EX_LAYERED = 0x00080000;
        public const int WS_EX_NOREDIRECTIONBITMAP = 0x00200000;
        public const int WS_EX_NOACTIVATE = 0x08000000;

        public const uint SWP_NOSIZE = 0x0001;
        public const uint SWP_NOMOVE = 0x0002;
        public const uint SWP_NOZORDER = 0x0004;
        public const uint SWP_NOACTIVATE = 0x0010;
        public const uint SWP_NOOWNERZORDER = 0x0200;

        public static readonly IntPtr HWND_TOP = IntPtr.Zero;
        public static readonly IntPtr HWND_BOTTOM = new IntPtr(1);
        public static readonly IntPtr HWND_NOTOPMOST = new IntPtr(-2);

        public const uint GW_HWNDNEXT = 2;
        public const uint GW_HWNDPREV = 3;
        public const uint GW_CHILD = 5;

        public const int WM_DESTROY = 0x0002;
        public const int WM_SETTINGCHANGE = 0x001A;
        public const int WM_MOUSEACTIVATE = 0x0021;
        public const int WM_WINDOWPOSCHANGING = 0x0046;
        public const int WM_CONTEXTMENU = 0x007B;
        public const int WM_DISPLAYCHANGE = 0x007E;
        public const int WM_DPICHANGED = 0x02E0;
        public const int WM_DPICHANGED_AFTERPARENT = 0x02E3;

        public const int MA_NOACTIVATE = 3;
        public const uint LWA_COLORKEY = 0x1;
        public const uint LWA_ALPHA = 0x2;
        public const int SW_SHOWNOACTIVATE = 4;
        public const int VK_LBUTTON = 0x01;
        public const int VK_RBUTTON = 0x02;
        public const int SPI_GETWORKAREA = 0x0030;
        public const int LOGPIXELSX = 88;
        public const uint MONITOR_DEFAULTTOPRIMARY = 1;
        public const int DWMWA_CLOAKED = 14;
        public const int DWMWA_EXCLUDED_FROM_PEEK = 12;

        public const uint EVENT_SYSTEM_FOREGROUND = 0x0003;
        public const uint EVENT_SYSTEM_MINIMIZESTART = 0x0016;
        public const uint EVENT_SYSTEM_MINIMIZEEND = 0x0017;
        public const uint WINEVENT_OUTOFCONTEXT = 0x0000;

        // DPI_AWARENESS_CONTEXT pseudo handles
        public static readonly IntPtr DPI_CTX_PER_MONITOR_V2 = new IntPtr(-4);

        [StructLayout(LayoutKind.Sequential)]
        public struct POINT
        {
            public int X;
            public int Y;
            public POINT(int x, int y) { X = x; Y = y; }
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct RECT
        {
            public int Left;
            public int Top;
            public int Right;
            public int Bottom;
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct WINDOWPOS
        {
            public IntPtr hwnd;
            public IntPtr hwndInsertAfter;
            public int x;
            public int y;
            public int cx;
            public int cy;
            public uint flags;
        }

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        public struct OSVERSIONINFOEX
        {
            public int dwOSVersionInfoSize;
            public int dwMajorVersion;
            public int dwMinorVersion;
            public int dwBuildNumber;
            public int dwPlatformId;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)]
            public string szCSDVersion;
            public ushort wServicePackMajor;
            public ushort wServicePackMinor;
            public ushort wSuiteMask;
            public byte wProductType;
            public byte wReserved;
        }

        public delegate void WinEventDelegate(IntPtr hWinEventHook, uint eventType, IntPtr hwnd,
            int idObject, int idChild, uint dwEventThread, uint dwmsEventTime);

        [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        public static extern IntPtr FindWindow(string lpClassName, string lpWindowName);
        [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        public static extern IntPtr FindWindowEx(IntPtr parent, IntPtr childAfter, string lpClassName, string lpWindowName);
        [DllImport("user32.dll")]
        public static extern IntPtr GetShellWindow();
        [DllImport("user32.dll", CharSet = CharSet.Unicode)]
        public static extern int GetClassName(IntPtr hWnd, StringBuilder lpClassName, int nMaxCount);
        [DllImport("user32.dll")]
        public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);

        [DllImport("user32.dll", SetLastError = true)]
        public static extern IntPtr GetParent(IntPtr hWnd);
        [DllImport("user32.dll", SetLastError = true)]
        public static extern IntPtr SetParent(IntPtr hWndChild, IntPtr hWndNewParent);
        [DllImport("user32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool IsWindow(IntPtr hWnd);
        [DllImport("user32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool IsWindowVisible(IntPtr hWnd);
        [DllImport("user32.dll", SetLastError = true)]
        public static extern IntPtr GetWindow(IntPtr hWnd, uint uCmd);

        [DllImport("user32.dll", EntryPoint = "GetWindowLongW", SetLastError = true)]
        private static extern int GetWindowLong32(IntPtr hWnd, int nIndex);
        [DllImport("user32.dll", EntryPoint = "GetWindowLongPtrW", SetLastError = true)]
        private static extern IntPtr GetWindowLongPtr64(IntPtr hWnd, int nIndex);
        [DllImport("user32.dll", EntryPoint = "SetWindowLongW", SetLastError = true)]
        private static extern int SetWindowLong32(IntPtr hWnd, int nIndex, int dwNewLong);
        [DllImport("user32.dll", EntryPoint = "SetWindowLongPtrW", SetLastError = true)]
        private static extern IntPtr SetWindowLongPtr64(IntPtr hWnd, int nIndex, IntPtr dwNewLong);

        public static int GetWindowLongInt(IntPtr hWnd, int index)
        {
            if (IntPtr.Size == 8) return unchecked((int)GetWindowLongPtr64(hWnd, index).ToInt64());
            return GetWindowLong32(hWnd, index);
        }

        public static void SetWindowLongInt(IntPtr hWnd, int index, int value)
        {
            if (IntPtr.Size == 8) SetWindowLongPtr64(hWnd, index, new IntPtr(value));
            else SetWindowLong32(hWnd, index, value);
        }

        [DllImport("user32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int x, int y, int cx, int cy, uint flags);
        [DllImport("user32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
        [DllImport("user32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);
        [DllImport("user32.dll", SetLastError = true)]
        public static extern int MapWindowPoints(IntPtr hWndFrom, IntPtr hWndTo, ref POINT pt, uint cPoints);
        [DllImport("user32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool ScreenToClient(IntPtr hWnd, ref POINT pt);
        [DllImport("user32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool GetCursorPos(out POINT pt);
        [DllImport("user32.dll")]
        public static extern short GetAsyncKeyState(int vKey);

        [DllImport("user32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool SetLayeredWindowAttributes(IntPtr hWnd, uint crKey, byte bAlpha, uint dwFlags);

        [DllImport("user32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool SetForegroundWindow(IntPtr hWnd);
        [DllImport("user32.dll")]
        public static extern IntPtr GetForegroundWindow();

        [DllImport("user32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool SystemParametersInfo(int uiAction, int uiParam, ref RECT pvParam, int fWinIni);
        [DllImport("user32.dll", CharSet = CharSet.Unicode)]
        public static extern uint RegisterWindowMessage(string lpString);

        [DllImport("user32.dll")]
        public static extern IntPtr SetWinEventHook(uint eventMin, uint eventMax, IntPtr hmodWinEventProc,
            WinEventDelegate lpfnWinEventProc, uint idProcess, uint idThread, uint dwFlags);
        [DllImport("user32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool UnhookWinEvent(IntPtr hWinEventHook);

        // ---- DPI (each wrapped in try/catch by callers: EntryPointNotFound on older builds)
        [DllImport("user32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool SetProcessDpiAwarenessContext(IntPtr value);
        [DllImport("user32.dll")]
        public static extern IntPtr SetThreadDpiAwarenessContext(IntPtr value);
        [DllImport("user32.dll")]
        public static extern IntPtr GetThreadDpiAwarenessContext();
        [DllImport("user32.dll")]
        public static extern IntPtr GetWindowDpiAwarenessContext(IntPtr hwnd);
        [DllImport("user32.dll")]
        public static extern int GetAwarenessFromDpiAwarenessContext(IntPtr value);
        [DllImport("user32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool AreDpiAwarenessContextsEqual(IntPtr a, IntPtr b);
        [DllImport("user32.dll")]
        public static extern uint GetDpiForSystem();
        [DllImport("user32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool SetProcessDPIAware();
        [DllImport("shcore.dll")]
        public static extern int SetProcessDpiAwareness(int value);
        [DllImport("shcore.dll")]
        public static extern int GetDpiForMonitor(IntPtr hmonitor, int dpiType, out uint dpiX, out uint dpiY);
        [DllImport("user32.dll")]
        public static extern IntPtr MonitorFromPoint(POINT pt, uint dwFlags);
        [DllImport("user32.dll")]
        public static extern IntPtr GetDC(IntPtr hWnd);
        [DllImport("user32.dll")]
        public static extern int ReleaseDC(IntPtr hWnd, IntPtr hDC);
        [DllImport("gdi32.dll")]
        public static extern int GetDeviceCaps(IntPtr hdc, int index);

        // ---- DIB tampon (GDI+ ayni bellege cizer, ekrana BitBlt ile hizli kopyalanir)
        [StructLayout(LayoutKind.Sequential)]
        public struct BITMAPINFOHEADER
        {
            public int biSize; public int biWidth; public int biHeight; public short biPlanes; public short biBitCount;
            public int biCompression; public int biSizeImage; public int biXPelsPerMeter; public int biYPelsPerMeter;
            public int biClrUsed; public int biClrImportant;
        }
        [DllImport("gdi32.dll")]
        public static extern IntPtr CreateDIBSection(IntPtr hdc, ref BITMAPINFOHEADER bmi, uint usage, out IntPtr bits, IntPtr section, uint offset);
        [DllImport("gdi32.dll")]
        public static extern IntPtr CreateCompatibleDC(IntPtr hdc);
        [DllImport("gdi32.dll")]
        public static extern IntPtr SelectObject(IntPtr hdc, IntPtr obj);
        [DllImport("gdi32.dll")]
        public static extern bool DeleteDC(IntPtr hdc);
        [DllImport("gdi32.dll")]
        public static extern bool DeleteObject(IntPtr obj);
        [DllImport("gdi32.dll")]
        public static extern bool BitBlt(IntPtr dst, int x, int y, int w, int h, IntPtr src, int sx, int sy, uint rop);
        public const uint SRCCOPY = 0x00CC0020;

        [DllImport("dwmapi.dll")]
        public static extern int DwmGetWindowAttribute(IntPtr hwnd, int attr, out int value, int size);
        [DllImport("dwmapi.dll")]
        public static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int value, int size);

        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool GetVersionEx(ref OSVERSIONINFOEX info);
        [DllImport("ntdll.dll", CharSet = CharSet.Unicode)]
        public static extern int RtlGetVersion(ref OSVERSIONINFOEX info);
    }

    // -----------------------------------------------------------------
    //  Static helpers usable from PowerShell:  [TaskbarKedileri.DesktopHost]::...
    // -----------------------------------------------------------------
    public static class DesktopHost
    {
        private static bool _dpiDone;
        private static string _dpiResult = "not-initialised";

        /// <summary>Result of InitDpi (for the log).</summary>
        public static string DpiResult { get { return _dpiResult; } }

        /// <summary>
        /// Make this process/thread Per-Monitor-V2 DPI aware BEFORE any window
        /// or WorkingArea query: real pixels (no DWM bitmap stretching, so pixel
        /// art stays crisp) and the same awareness as explorer.exe, which is
        /// required for a cross-process parent/child relationship.
        /// Idempotent; safe to call repeatedly.
        /// </summary>
        public static string InitDpi()
        {
            if (_dpiDone) return _dpiResult;
            _dpiDone = true;
            try
            {
                if (Native.SetProcessDpiAwarenessContext(Native.DPI_CTX_PER_MONITOR_V2))
                {
                    _dpiResult = "process:PerMonitorV2";
                    return _dpiResult;
                }
            }
            catch (Exception) { }
            try
            {
                if (Native.AreDpiAwarenessContextsEqual(Native.GetThreadDpiAwarenessContext(), Native.DPI_CTX_PER_MONITOR_V2))
                {
                    _dpiResult = "already:PerMonitorV2";
                    return _dpiResult;
                }
                IntPtr old = Native.SetThreadDpiAwarenessContext(Native.DPI_CTX_PER_MONITOR_V2);
                if (old != IntPtr.Zero)
                {
                    _dpiResult = "thread:PerMonitorV2";
                    return _dpiResult;
                }
            }
            catch (Exception) { }
            try
            {
                if (Native.SetProcessDpiAwareness(2) == 0)
                {
                    _dpiResult = "process:PerMonitorV1(shcore)";
                    return _dpiResult;
                }
            }
            catch (Exception) { }
            try
            {
                if (Native.SetProcessDPIAware())
                {
                    _dpiResult = "process:SystemAware";
                    return _dpiResult;
                }
            }
            catch (Exception) { }
            _dpiResult = "unaware(DWM will bitmap-stretch)";
            return _dpiResult;
        }

        /// <summary>Effective DPI of the primary monitor, as seen by this thread.</summary>
        public static int GetPrimaryDpi()
        {
            try
            {
                IntPtr mon = Native.MonitorFromPoint(new Native.POINT(0, 0), Native.MONITOR_DEFAULTTOPRIMARY);
                uint dx, dy;
                if (mon != IntPtr.Zero && Native.GetDpiForMonitor(mon, 0, out dx, out dy) == 0 && dx > 0) return (int)dx;
            }
            catch (Exception) { }
            try
            {
                uint d = Native.GetDpiForSystem();
                if (d > 0) return (int)d;
            }
            catch (Exception) { }
            IntPtr hdc = Native.GetDC(IntPtr.Zero);
            try
            {
                int v = Native.GetDeviceCaps(hdc, Native.LOGPIXELSX);
                return v > 0 ? v : 96;
            }
            finally { Native.ReleaseDC(IntPtr.Zero, hdc); }
        }

        /// <summary>Integer pixel multiplier for crisp pixel art: 100-125% -> 1, 150-225% -> 2, ...</summary>
        public static int GetPixelScale()
        {
            int s = (int)Math.Floor(GetPrimaryDpi() / 96.0 + 0.5);
            return s < 1 ? 1 : s;
        }

        /// <summary>Primary monitor work area in this thread's DPI units (physical px when PMv2).</summary>
        public static Rectangle GetWorkArea()
        {
            Native.RECT r = new Native.RECT();
            if (Native.SystemParametersInfo(Native.SPI_GETWORKAREA, 0, ref r, 0) && r.Right > r.Left && r.Bottom > r.Top)
                return Rectangle.FromLTRB(r.Left, r.Top, r.Right, r.Bottom);
            return Screen.PrimaryScreen.WorkingArea;
        }

        public static string GetClass(IntPtr hwnd)
        {
            if (hwnd == IntPtr.Zero) return "";
            StringBuilder sb = new StringBuilder(256);
            Native.GetClassName(hwnd, sb, sb.Capacity);
            return sb.ToString();
        }

        public static bool ClassIs(IntPtr hwnd, string cls)
        {
            return string.Equals(GetClass(hwnd), cls, StringComparison.OrdinalIgnoreCase);
        }

        public static bool IsCloaked(IntPtr hwnd)
        {
            try
            {
                int v;
                return Native.DwmGetWindowAttribute(hwnd, Native.DWMWA_CLOAKED, out v, 4) == 0 && v != 0;
            }
            catch (Exception) { return false; }
        }

        /// <summary>
        /// Top-level window that currently hosts SHELLDLL_DefView (the desktop icons):
        ///   Progman with WS_EX_NOREDIRECTIONBITMAP -> Windows 11 24H2+ "raised desktop"
        ///   Progman                                -> plain Win10 / Win11 desktop
        ///   WorkerW                                -> older tree after 0x052C / slideshow
        /// Returns IntPtr.Zero when Explorer is not running (yet).
        /// </summary>
        public static IntPtr FindIconHost(out string layout)
        {
            layout = "none";
            IntPtr shell = Native.GetShellWindow();
            uint shellPid = 0;
            if (shell != IntPtr.Zero) Native.GetWindowThreadProcessId(shell, out shellPid);

            IntPtr progman = Native.FindWindow("Progman", null);
            if (progman != IntPtr.Zero && Native.FindWindowEx(progman, IntPtr.Zero, "SHELLDLL_DefView", null) != IntPtr.Zero)
            {
                int ex = Native.GetWindowLongInt(progman, Native.GWL_EXSTYLE);
                layout = (ex & Native.WS_EX_NOREDIRECTIONBITMAP) != 0 ? "Progman/raised(24H2+)" : "Progman/classic";
                return progman;
            }
            IntPtr w = IntPtr.Zero;
            for (int guard = 0; guard < 256; guard++)
            {
                w = Native.FindWindowEx(IntPtr.Zero, w, "WorkerW", null);
                if (w == IntPtr.Zero) break;
                if (Native.FindWindowEx(w, IntPtr.Zero, "SHELLDLL_DefView", null) == IntPtr.Zero) continue;
                if (shellPid != 0)
                {
                    uint pid;
                    Native.GetWindowThreadProcessId(w, out pid);
                    if (pid != shellPid) continue;
                }
                layout = "WorkerW/classic";
                return w;
            }
            return IntPtr.Zero;
        }

        /// <summary>null when our thread and the host window have the same DPI awareness, else the reason.</summary>
        public static string CheckDpiCompat(IntPtr host)
        {
            try
            {
                int ha = Native.GetAwarenessFromDpiAwarenessContext(Native.GetWindowDpiAwarenessContext(host));
                int ta = Native.GetAwarenessFromDpiAwarenessContext(Native.GetThreadDpiAwarenessContext());
                if (ha < 0 || ta < 0) return null; // unknown -> let creation/verification decide
                if (ha != ta)
                    return string.Format("DPI awareness mismatch (explorer={0}, widget={1})", AwarenessName(ha), AwarenessName(ta));
            }
            catch (Exception) { }
            return null;
        }

        public static string ThreadAwareness()
        {
            try
            {
                IntPtr ctx = Native.GetThreadDpiAwarenessContext();
                if (Native.AreDpiAwarenessContextsEqual(ctx, Native.DPI_CTX_PER_MONITOR_V2)) return "PerMonitorV2";
                return AwarenessName(Native.GetAwarenessFromDpiAwarenessContext(ctx));
            }
            catch (Exception) { return "n/a"; }
        }

        private static string AwarenessName(int a)
        {
            if (a == 0) return "Unaware";
            if (a == 1) return "System";
            if (a == 2) return "PerMonitor";
            return "Invalid";
        }

        /// <summary>Real OS version (RtlGetVersion).</summary>
        public static string OsVersion
        {
            get
            {
                try
                {
                    Native.OSVERSIONINFOEX v = new Native.OSVERSIONINFOEX();
                    v.dwOSVersionInfoSize = Marshal.SizeOf(typeof(Native.OSVERSIONINFOEX));
                    if (Native.RtlGetVersion(ref v) == 0)
                        return string.Format("{0}.{1}.{2}", v.dwMajorVersion, v.dwMinorVersion, v.dwBuildNumber);
                }
                catch (Exception) { }
                return Environment.OSVersion.Version.ToString();
            }
        }

        /// <summary>
        /// Version as reported by GetVersionEx, which is capped by the host EXE's
        /// manifest (supportedOS).  "10.0.x" => powershell.exe declares Windows 10
        /// compatibility, which also satisfies the Win8+ requirement for layered
        /// CHILD windows.  "6.2.x" => not manifested for 8.1+.
        /// </summary>
        public static string ManifestOsVersion
        {
            get
            {
                try
                {
                    Native.OSVERSIONINFOEX v = new Native.OSVERSIONINFOEX();
                    v.dwOSVersionInfoSize = Marshal.SizeOf(typeof(Native.OSVERSIONINFOEX));
                    if (Native.GetVersionEx(ref v))
                        return string.Format("{0}.{1}.{2}", v.dwMajorVersion, v.dwMinorVersion, v.dwBuildNumber);
                }
                catch (Exception) { }
                return "n/a";
            }
        }

        /// <summary>One line describing the desktop window tree (for catbar-hata.log).</summary>
        public static string Describe()
        {
            StringBuilder sb = new StringBuilder();
            string layout;
            IntPtr host = FindIconHost(out layout);
            sb.AppendFormat("os={0} exeManifestOs={1} dpiInit={2} thread={3} primaryDpi={4} workArea={5} host=0x{6:X}({7}) layout={8}",
                OsVersion, ManifestOsVersion, _dpiResult, ThreadAwareness(), GetPrimaryDpi(), GetWorkArea(),
                host.ToInt64(), GetClass(host), layout);
            if (host != IntPtr.Zero)
            {
                sb.Append(" children=[");
                IntPtr c = Native.GetWindow(host, Native.GW_CHILD);
                for (int i = 0; c != IntPtr.Zero && i < 16; i++)
                {
                    if (i > 0) sb.Append(", ");
                    sb.AppendFormat("{0}{1}", GetClass(c),
                        (Native.GetWindowLongInt(c, Native.GWL_EXSTYLE) & Native.WS_EX_LAYERED) != 0 ? "(layered)" : "");
                    c = Native.GetWindow(c, Native.GW_HWNDNEXT);
                }
                sb.Append("]");
            }
            return sb.ToString();
        }
    }

    // -----------------------------------------------------------------
    //  Hidden top-level window: receives the broadcasts a WS_CHILD never
    //  gets (WM_SETTINGCHANGE / WM_DISPLAYCHANGE / "TaskbarCreated") and is
    //  the foreground anchor while the context menu is open.
    // -----------------------------------------------------------------
    internal sealed class SinkWindow : NativeWindow
    {
        private readonly DesktopForm _owner;
        private readonly int _taskbarCreated;

        public SinkWindow(DesktopForm owner)
        {
            _owner = owner;
            _taskbarCreated = (int)Native.RegisterWindowMessage("TaskbarCreated");
            CreateParams cp = new CreateParams();
            cp.Caption = "TaskbarKedileriSink";
            cp.Style = Native.WS_POPUP;
            cp.ExStyle = Native.WS_EX_TOOLWINDOW;
            cp.X = 0; cp.Y = 0; cp.Width = 0; cp.Height = 0;
            CreateHandle(cp);
        }

        protected override void WndProc(ref Message m)
        {
            try
            {
                if (m.Msg == Native.WM_SETTINGCHANGE || m.Msg == Native.WM_DISPLAYCHANGE || m.Msg == Native.WM_DPICHANGED)
                    _owner.NotifySystemChange();
                else if (_taskbarCreated != 0 && m.Msg == _taskbarCreated)
                    _owner.NotifyExplorerRestarted();
            }
            catch (Exception) { }
            base.WndProc(ref m);
        }
    }

    // -----------------------------------------------------------------
    //  The widget form.  Use instead of System.Windows.Forms.Form:
    //     $form = New-Object TaskbarKedileri.DesktopForm
    //  Bounds/Location stay in SCREEN coordinates in every mode.
    // -----------------------------------------------------------------
    public class DesktopForm : Form
    {
        private const int ActiveNone = 0;
        private const int ActiveDesktop = 1;
        private const int ActiveBottom = 2;
        private const int WatchIntervalMs = 250;
        private const int HitIntervalMs = 30;
        private const int HitIdleIntervalMs = 100;
        private const int HostLostGiveUpMs = 15000;
        private const int BottomRetryDesktopMs = 4000;
        private const int MaxLogChars = 16000;

        private DesktopModeRequest _requested = DesktopModeRequest.Auto;
        private int _active = ActiveNone;
        private string _mode = "None";
        private string _modeDetail = "";
        private IntPtr _host = IntPtr.Zero;      // Desktop mode: our parent
        private string _layout = "";
        private bool _wantChild;                 // decided right before CreateHandle
        private string _desktopBlocked;          // hard failure -> stay in Bottom
        private bool _hostLost;
        private int _hostLostSince;
        private int _parentRepairs;
        private int _bottomSince;
        private bool _allowZ;
        private bool _selfDestroy;
        private bool _closing;
        private bool _hitTestByMask = true;
        private bool _clickThrough = true;
        private int _hitSlop = 2;
        private Rectangle _desiredBounds = Rectangle.Empty;   // screen coordinates
        private Bitmap _buffer;
        private Graphics _bufG;                 // tampona kalici Graphics (her boyamada yeniden olusturulmaz)

        /// <summary>Bir sonraki WM_PAINT'te yalnizca bu dikdortgenler yeniden olusturulur
        /// (birden cok kucuk alan tek bir boyama mesajinda). null: ClipRectangle'in tamami.</summary>
        public IList<Rectangle> DirtyHint;
        private IntPtr _bufDC = IntPtr.Zero, _bufHbm = IntPtr.Zero, _bufOld = IntPtr.Zero;
        private readonly System.Windows.Forms.Timer _watch;
        private readonly System.Windows.Forms.Timer _hit;
        private SinkWindow _sink;
        private readonly Native.WinEventDelegate _winEventProc;   // kept alive (GC!)
        private IntPtr _hookFg = IntPtr.Zero;
        private IntPtr _hookMin = IntPtr.Zero;
        private int _zBurstUntil;
        private int _zFixes;
        private int _zFixWindowStart;
        private Rectangle _lastWorkArea = Rectangle.Empty;
        private int _lastDpi;
        private IntPtr _prevForeground = IntPtr.Zero;
        private ContextMenuStrip _hookedMenu;
        private readonly StringBuilder _log = new StringBuilder();

        public event EventHandler WorkAreaChanged;
        public event EventHandler ModeChanged;
        public event EventHandler<DesktopLogEventArgs> LogMessage;

        static DesktopForm()
        {
            DesktopHost.InitDpi();
        }

        public DesktopForm()
        {
            FormBorderStyle = FormBorderStyle.None;
            ShowInTaskbar = false;
            StartPosition = FormStartPosition.Manual;
            AutoScaleMode = AutoScaleMode.None;
            Text = "Taskbar Kedileri";
            // Kendi tamponumuz var (DIB + BitBlt); WinForms'un ikinci tamponu her WM_PAINT'te
            // bos yere bellek ayirip kopyaliyordu -> kapali.
            SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.UserPaint | ControlStyles.Opaque, true);
            SetStyle(ControlStyles.OptimizedDoubleBuffer | ControlStyles.DoubleBuffer, false);

            _winEventProc = new Native.WinEventDelegate(OnWinEvent);
            _watch = new System.Windows.Forms.Timer();
            _watch.Interval = WatchIntervalMs;
            _watch.Tick += OnWatchTick;
            _hit = new System.Windows.Forms.Timer();
            _hit.Interval = HitIntervalMs;
            _hit.Tick += OnHitTick;
        }

        // ============================================================ public API

        /// <summary>Auto (default) / Desktop / Bottom. Changing it at runtime re-creates the window.</summary>
        [Browsable(false)]
        public DesktopModeRequest RequestedMode
        {
            get { return _requested; }
            set
            {
                bool unblocked = false;
                if (value == DesktopModeRequest.Desktop && _desktopBlocked != null)
                {
                    _desktopBlocked = null;   // explicit user override: try again
                    unblocked = true;
                }
                if (_requested == value && !unblocked) return;
                _requested = value;
                Log("requested mode -> " + value);
                if (IsHandleCreated) BeginInvoke(new MethodInvoker(SafeRecreate));
            }
        }

        /// <summary>Active mode: "Desktop", "Bottom" or "None" (no window right now).</summary>
        public string Mode { get { return _mode; } }

        /// <summary>Host window, layout, DPI, OS and manifest details of the active mode.</summary>
        public string ModeDetail { get { return _modeDetail; } }

        /// <summary>Why Desktop mode was abandoned for this session (null if it was not).</summary>
        public string DesktopFailure { get { return _desktopBlocked; } }

        /// <summary>Accumulated diagnostic log (also raised line by line via LogMessage).</summary>
        public string Diagnostics { get { return _log.ToString(); } }

        /// <summary>Toggle WS_EX_TRANSPARENT from the back buffer so key-colour pixels never catch clicks.</summary>
        public bool HitTestByMask
        {
            get { return _hitTestByMask; }
            set { _hitTestByMask = value; if (IsHandleCreated) UpdateClickThrough(true); }
        }

        /// <summary>Extra pixels around opaque pixels that still count as a hit (default 2).</summary>
        public int HitSlop
        {
            get { return _hitSlop; }
            set { _hitSlop = value < 0 ? 0 : value; }
        }

        public int Dpi { get { return DesktopHost.GetPrimaryDpi(); } }
        public int PixelScale { get { return DesktopHost.GetPixelScale(); } }
        public IntPtr HostWindow { get { return _host; } }

        /// <summary>Re-run host discovery and re-create the window (keeps state).</summary>
        public void Reattach()
        {
            if (_requested != DesktopModeRequest.Bottom) _desktopBlocked = null;
            if (IsHandleCreated) BeginInvoke(new MethodInvoker(SafeRecreate));
        }

        /// <summary>True when the last painted frame has a non-key pixel at client (x, y) (+/- HitSlop).</summary>
        public bool IsOpaqueAt(int x, int y)
        {
            Bitmap b = _buffer;
            if (b == null) return false;
            Color key = TransparencyKey;
            if (key.IsEmpty) return x >= 0 && y >= 0 && x < b.Width && y < b.Height;
            int k = key.ToArgb();
            int s = _hitSlop;
            if (PixelOpaque(b, x, y, k)) return true;
            if (s <= 0) return false;
            return PixelOpaque(b, x - s, y, k) || PixelOpaque(b, x + s, y, k)
                || PixelOpaque(b, x, y - s, k) || PixelOpaque(b, x, y + s, k);
        }

        private static bool PixelOpaque(Bitmap b, int x, int y, int keyArgb)
        {
            if (x < 0 || y < 0 || x >= b.Width || y >= b.Height) return false;
            return b.GetPixel(x, y).ToArgb() != keyArgb;
        }

        // ============================================================ window creation

        protected override bool ShowWithoutActivation { get { return true; } }

        protected override CreateParams CreateParams
        {
            get
            {
                CreateParams cp = base.CreateParams;
                cp.ExStyle &= ~(Native.WS_EX_TOPMOST | Native.WS_EX_APPWINDOW);
                cp.ExStyle |= Native.WS_EX_LAYERED | Native.WS_EX_NOACTIVATE;
                if (_hitTestByMask && _clickThrough) cp.ExStyle |= Native.WS_EX_TRANSPARENT;
                else cp.ExStyle &= ~Native.WS_EX_TRANSPARENT;

                if (_wantChild && _host != IntPtr.Zero)
                {
                    cp.Parent = _host;
                    cp.Style &= ~(Native.WS_POPUP | Native.WS_CAPTION | Native.WS_THICKFRAME | Native.WS_SYSMENU
                                  | Native.WS_MINIMIZEBOX | Native.WS_MAXIMIZEBOX);
                    cp.Style |= Native.WS_CHILD | Native.WS_CLIPSIBLINGS;
                    cp.ExStyle &= ~Native.WS_EX_TOOLWINDOW;
                    Rectangle r = _desiredBounds.IsEmpty ? new Rectangle(cp.X, cp.Y, cp.Width, cp.Height) : _desiredBounds;
                    Native.POINT p = new Native.POINT(r.X, r.Y);
                    Native.MapWindowPoints(IntPtr.Zero, _host, ref p, 1);   // screen -> host client
                    cp.X = p.X; cp.Y = p.Y; cp.Width = r.Width; cp.Height = r.Height;
                }
                else
                {
                    // Unowned popup: WinForms would make it owned by a hidden "taskbar owner"
                    // window (ShowInTaskbar=false), which complicates z-order handling.
                    cp.Parent = IntPtr.Zero;
                    cp.Style = (cp.Style & ~Native.WS_CHILD) | Native.WS_POPUP;
                    cp.ExStyle |= Native.WS_EX_TOOLWINDOW;
                }
                return cp;
            }
        }

        protected override void CreateHandle()
        {
            if (_closing) { base.CreateHandle(); return; }
            DecideMode();
            if (_wantChild)
            {
                try
                {
                    base.CreateHandle();
                    return;
                }
                catch (Exception ex)
                {
                    BlockDesktop("CreateWindowEx(WS_CHILD of " + _layout + ") failed: " + ex.Message);
                    _wantChild = false;
                    _host = IntPtr.Zero;
                }
            }
            base.CreateHandle();
        }

        private void DecideMode()
        {
            _wantChild = false;
            _host = IntPtr.Zero;
            _layout = "";
            if (_requested == DesktopModeRequest.Bottom) return;
            if (_desktopBlocked != null) return;
            string layout;
            IntPtr host = DesktopHost.FindIconHost(out layout);
            if (host == IntPtr.Zero)
            {
                Log("no SHELLDLL_DefView host found (Explorer not ready?) -> Bottom for now");
                return;
            }
            string why = DesktopHost.CheckDpiCompat(host);
            if (why != null) { BlockDesktop(why); return; }
            _host = host;
            _layout = layout;
            _wantChild = true;
        }

        protected override void OnHandleCreated(EventArgs e)
        {
            base.OnHandleCreated(e);
            bool layeredOk = ApplyLayered();

            if (_wantChild)
            {
                string fail = null;
                int ex = Native.GetWindowLongInt(Handle, Native.GWL_EXSTYLE);
                if (Native.GetParent(Handle) != _host) fail = "window did not become a child of " + _layout;
                else if ((ex & Native.WS_EX_LAYERED) == 0) fail = "WS_EX_LAYERED was dropped on the child (layered child windows need a Win8+ manifest)";
                else if (!layeredOk) fail = "SetLayeredWindowAttributes failed on the child";

                if (fail != null)
                {
                    BlockDesktop(fail);
                    _wantChild = false;
                    _active = ActiveNone;
                    BeginInvoke(new MethodInvoker(SafeRecreate));
                }
                else
                {
                    _active = ActiveDesktop;
                    _parentRepairs = 0;
                    UnhookEvents();
                    RaiseInHost();
                    SetMode("Desktop", BuildDetail());
                    // OnHandleCreated runs inside WM_CREATE; Form.CreateHandle still has code to
                    // run after it, so verify the parent again once creation has fully finished.
                    BeginInvoke(new MethodInvoker(VerifyParent));
                }
            }
            else
            {
                _active = ActiveBottom;
                _bottomSince = Environment.TickCount;
                HookEvents();
                ExcludeFromPeek();
                EnsureAboveDesktop(true);
                SetMode("Bottom", BuildDetail());
            }

            if (_sink == null)
            {
                try { _sink = new SinkWindow(this); }
                catch (Exception ex2) { Log("sink window failed: " + ex2.Message); }
            }
            if (_lastWorkArea.IsEmpty)
            {
                _lastWorkArea = DesktopHost.GetWorkArea();
                _lastDpi = DesktopHost.GetPrimaryDpi();
            }
            _watch.Start();
            _hit.Start();
            UpdateClickThrough(true);
        }

        private bool ApplyLayered()
        {
            int ex = Native.GetWindowLongInt(Handle, Native.GWL_EXSTYLE);
            if ((ex & Native.WS_EX_LAYERED) == 0) Native.SetWindowLongInt(Handle, Native.GWL_EXSTYLE, ex | Native.WS_EX_LAYERED);
            uint flags = Native.LWA_ALPHA;
            uint key = 0;
            Color k = TransparencyKey;
            if (!k.IsEmpty)
            {
                flags |= Native.LWA_COLORKEY;
                key = (uint)(k.R | (k.G << 8) | (k.B << 16));
            }
            double op = Opacity;
            byte alpha = (byte)Math.Max(0, Math.Min(255, (int)Math.Round(op * 255.0)));
            bool ok = Native.SetLayeredWindowAttributes(Handle, key, alpha, flags);
            if (!ok) Log("SetLayeredWindowAttributes failed, win32 error " + Marshal.GetLastWin32Error());
            return ok;
        }

        protected override void DestroyHandle()
        {
            _selfDestroy = true;
            try { base.DestroyHandle(); }
            finally { _selfDestroy = false; }
        }

        private void SafeRecreate()
        {
            try
            {
                if (_closing || IsDisposed) return;
                if (IsHandleCreated) RecreateHandle();
                else { CreateControl(); if (!IsHandleCreated) CreateHandle(); }
                ScheduleWorkAreaCheck(true);
            }
            catch (Exception ex) { Log("recreate failed: " + ex.Message); }
        }

        private void BlockDesktop(string reason)
        {
            _desktopBlocked = reason;
            Log("Desktop mode unavailable: " + reason + " -> Bottom");
        }

        private string BuildDetail()
        {
            return string.Format("host=0x{0:X}({1}) layout={2} dpi={3} pixelScale={4} dpiInit={5} os={6} exeManifestOs={7}{8}",
                _host.ToInt64(), DesktopHost.GetClass(_host), _layout == "" ? "-" : _layout,
                DesktopHost.GetPrimaryDpi(), DesktopHost.GetPixelScale(), DesktopHost.DpiResult,
                DesktopHost.OsVersion, DesktopHost.ManifestOsVersion,
                _desktopBlocked == null ? "" : " fallbackReason=\"" + _desktopBlocked + "\"");
        }

        private void SetMode(string mode, string detail)
        {
            bool changed = mode != _mode || detail != _modeDetail;
            _mode = mode;
            _modeDetail = detail;
            if (!changed) return;
            AppendLog("mode=" + mode + " " + detail);
            EventHandler h = ModeChanged;
            if (h != null)
            {
                try { h(this, EventArgs.Empty); }
                catch (Exception ex) { AppendLog("ModeChanged handler: " + ex.Message); }
            }
        }

        // ============================================================ bounds (screen coordinates)

        protected override void SetBoundsCore(int x, int y, int width, int height, BoundsSpecified specified)
        {
            _desiredBounds = new Rectangle(x, y, width, height);
            if (IsHandleCreated && _active == ActiveDesktop && _host != IntPtr.Zero)
            {
                MoveChild();
                return;
            }
            base.SetBoundsCore(x, y, width, height, specified);
        }

        private void MoveChild()
        {
            Rectangle r = _desiredBounds.IsEmpty ? Bounds : _desiredBounds;
            Native.POINT p = new Native.POINT(r.X, r.Y);
            Native.MapWindowPoints(IntPtr.Zero, _host, ref p, 1);
            Native.SetWindowPos(Handle, IntPtr.Zero, p.X, p.Y, r.Width, r.Height, Native.SWP_NOZORDER | Native.SWP_NOACTIVATE);
            // WM_WINDOWPOSCHANGED -> WinForms reads GetWindowRect (screen) because the
            // form is still TopLevel for WinForms, so Bounds stays in screen coordinates.
        }

        // ============================================================ messages

        protected override void WndProc(ref Message m)
        {
            switch (m.Msg)
            {
                case Native.WM_MOUSEACTIVATE:
                    m.Result = new IntPtr(Native.MA_NOACTIVATE);   // clicks never activate / raise us
                    return;

                case Native.WM_WINDOWPOSCHANGING:
                    if (_active == ActiveBottom && !_allowZ && m.LParam != IntPtr.Zero)
                    {
                        Native.WINDOWPOS wp = (Native.WINDOWPOS)Marshal.PtrToStructure(m.LParam, typeof(Native.WINDOWPOS));
                        if ((wp.flags & Native.SWP_NOZORDER) == 0)
                        {
                            wp.flags |= Native.SWP_NOZORDER;           // only our own code moves us in z
                            Marshal.StructureToPtr(wp, m.LParam, false);
                        }
                    }
                    break;

                case Native.WM_CONTEXTMENU:
                    PrepareMenuForeground();
                    break;

                case Native.WM_DPICHANGED:
                case Native.WM_DPICHANGED_AFTERPARENT:
                    base.WndProc(ref m);
                    ScheduleWorkAreaCheck(true);
                    return;

                case Native.WM_SETTINGCHANGE:
                case Native.WM_DISPLAYCHANGE:
                    base.WndProc(ref m);
                    ScheduleWorkAreaCheck(false);
                    return;

                case Native.WM_DESTROY:
                    if (!_selfDestroy && !_closing && !RecreatingHandle && _active == ActiveDesktop)
                    {
                        // Explorer died: the system destroys its windows' children, us included.
                        _hostLost = true;
                        _hostLostSince = Environment.TickCount;
                        _active = ActiveNone;
                        _host = IntPtr.Zero;
                        SetMode("None", "desktop host destroyed (Explorer restart?) - waiting to re-attach");
                    }
                    break;
            }
            base.WndProc(ref m);
        }

        // ============================================================ painting + mask

        protected override void OnPaintBackground(PaintEventArgs e)
        {
            // everything (including the key colour) is painted in OnPaint
        }

        // olcum (KediWidget.Stats -> CATBAR_PERF log satiri)
        private readonly System.Diagnostics.Stopwatch _paintSw = new System.Diagnostics.Stopwatch();
        private readonly System.Diagnostics.Stopwatch _hitSw = new System.Diagnostics.Stopwatch();
        private long _paintCount, _paintPixels, _hitCount;
        public string PerfStats()
        {
            return string.Format(System.Globalization.CultureInfo.InvariantCulture,
                "wm_paint={0} ({1:F3}ms ort, {2:F0}k px ort) hit={3} ({4:F3}ms ort, {5}ms aralik)",
                _paintCount, _paintCount > 0 ? _paintSw.Elapsed.TotalMilliseconds / _paintCount : 0,
                _paintCount > 0 ? _paintPixels / 1000.0 / _paintCount : 0,
                _hitCount, _hitCount > 0 ? _hitSw.Elapsed.TotalMilliseconds / _hitCount : 0, _hit.Interval);
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            _paintSw.Start();
            try { PaintBuffered(e); }
            finally { _paintSw.Stop(); _paintCount++; }
        }

        private void FreeBuffer()
        {
            if (_bufG != null) { _bufG.Dispose(); _bufG = null; }
            if (_buffer != null) { _buffer.Dispose(); _buffer = null; }
            if (_bufDC != IntPtr.Zero) { Native.SelectObject(_bufDC, _bufOld); Native.DeleteDC(_bufDC); _bufDC = IntPtr.Zero; }
            if (_bufHbm != IntPtr.Zero) { Native.DeleteObject(_bufHbm); _bufHbm = IntPtr.Zero; }
        }

        private void AllocBuffer(int w, int h)
        {
            FreeBuffer();
            try
            {
                Native.BITMAPINFOHEADER bi = new Native.BITMAPINFOHEADER();
                bi.biSize = Marshal.SizeOf(typeof(Native.BITMAPINFOHEADER));
                bi.biWidth = w; bi.biHeight = -h;           // ust-alt sirali
                bi.biPlanes = 1; bi.biBitCount = 32;        // BI_RGB
                IntPtr bits;
                IntPtr hbm = Native.CreateDIBSection(IntPtr.Zero, ref bi, 0, out bits, IntPtr.Zero, 0);
                IntPtr dc = hbm != IntPtr.Zero ? Native.CreateCompatibleDC(IntPtr.Zero) : IntPtr.Zero;
                if (hbm != IntPtr.Zero && dc != IntPtr.Zero && bits != IntPtr.Zero)
                {
                    _bufHbm = hbm; _bufDC = dc;
                    _bufOld = Native.SelectObject(dc, hbm);
                    _buffer = new Bitmap(w, h, w * 4, PixelFormat.Format32bppPArgb, bits);
                }
                else
                {
                    if (dc != IntPtr.Zero) Native.DeleteDC(dc);
                    if (hbm != IntPtr.Zero) Native.DeleteObject(hbm);
                }
            }
            catch (Exception) { _bufDC = IntPtr.Zero; _bufHbm = IntPtr.Zero; }
            if (_buffer == null) _buffer = new Bitmap(w, h, PixelFormat.Format32bppPArgb);   // yedek: yonetilen tampon
            _bufG = Graphics.FromImage(_buffer);
        }

        private void PaintBuffered(PaintEventArgs e)
        {
            Size cs = ClientSize;
            if (cs.Width <= 0 || cs.Height <= 0) { base.OnPaint(e); return; }
            Rectangle full = new Rectangle(0, 0, cs.Width, cs.Height);
            // Yalnizca gecersiz kilinan alan yeniden olusturulur; tampon arada korunur
            // (KediWidget yalnizca degisen sprite'lari gecersiz kilar).
            Rectangle clip = Rectangle.Intersect(e.ClipRectangle, full);
            if (_buffer == null || _buffer.Width != cs.Width || _buffer.Height != cs.Height)
            {
                AllocBuffer(cs.Width, cs.Height);
                clip = full;
            }
            if (clip.Width <= 0 || clip.Height <= 0) return;

            List<Rectangle> parts = new List<Rectangle>();
            IList<Rectangle> hint = DirtyHint;
            DirtyHint = null;
            if (hint != null && hint.Count > 0 && clip != full)
            {
                Rectangle bbox = Rectangle.Empty;
                foreach (Rectangle h0 in hint)
                {
                    Rectangle h = Rectangle.Intersect(h0, clip);
                    if (h.Width <= 0 || h.Height <= 0) continue;
                    parts.Add(h);
                    bbox = bbox.IsEmpty ? h : Rectangle.Union(bbox, h);
                }
                // sistem de baska bir yeri gecersiz kildiysa (ipucunun disinda) tamamini boya
                if (bbox != clip) parts.Clear();
            }
            if (parts.Count == 0) parts.Add(clip);

            Color bg = TransparencyKey.IsEmpty ? BackColor : TransparencyKey;
            Graphics g = _bufG;
            using (SolidBrush b = new SolidBrush(bg))
            {
                foreach (Rectangle r in parts)
                {
                    _paintPixels += (long)r.Width * r.Height;
                    g.SetClip(r);
                    g.CompositingMode = CompositingMode.SourceCopy;
                    g.FillRectangle(b, r);
                    g.CompositingMode = CompositingMode.SourceOver;
                    base.OnPaint(new PaintEventArgs(g, r));   // KediWidget.OnPaint
                }
            }
            g.ResetClip();

            Graphics sg = e.Graphics;
            if (_bufDC != IntPtr.Zero)
            {
                g.Flush(FlushIntention.Sync);
                IntPtr hdc = sg.GetHdc();
                try
                {
                    foreach (Rectangle r in parts)
                        Native.BitBlt(hdc, r.X, r.Y, r.Width, r.Height, _bufDC, r.X, r.Y, Native.SRCCOPY);
                }
                finally { sg.ReleaseHdc(hdc); }
            }
            else
            {
                sg.CompositingMode = CompositingMode.SourceCopy;
                sg.InterpolationMode = InterpolationMode.NearestNeighbor;
                sg.PixelOffsetMode = PixelOffsetMode.Half;
                foreach (Rectangle r in parts)
                    sg.DrawImage(_buffer, r, r.X, r.Y, r.Width, r.Height, GraphicsUnit.Pixel);
            }
        }

        private void UpdateClickThrough(bool force)
        {
            if (!IsHandleCreated) return;
            if (!_hitTestByMask) { SetClickThrough(false, force); return; }
            if (!force)
            {
                if ((Native.GetAsyncKeyState(Native.VK_LBUTTON) & 0x8000) != 0) return;
                if ((Native.GetAsyncKeyState(Native.VK_RBUTTON) & 0x8000) != 0) return;
                ContextMenuStrip cms = ContextMenuStrip;
                if (cms != null && cms.Visible) return;
            }
            bool opaque = false;
            bool inside = false;
            Native.POINT p;
            Native.RECT r;
            if (Native.GetCursorPos(out p) && Native.GetWindowRect(Handle, out r)
                && p.X >= r.Left && p.X < r.Right && p.Y >= r.Top && p.Y < r.Bottom)
            {
                inside = true;
                Native.ScreenToClient(Handle, ref p);
                opaque = IsOpaqueAt(p.X, p.Y);
            }
            // imlec seridin disindayken daha seyrek bak (gereksiz uyanma yok)
            int want = inside ? HitIntervalMs : HitIdleIntervalMs;
            if (_hit.Interval != want) _hit.Interval = want;
            SetClickThrough(!opaque, force);
        }

        private void SetClickThrough(bool on, bool force)
        {
            if (!force && on == _clickThrough) return;
            _clickThrough = on;
            int ex = Native.GetWindowLongInt(Handle, Native.GWL_EXSTYLE);
            int nex = on ? (ex | Native.WS_EX_TRANSPARENT) : (ex & ~Native.WS_EX_TRANSPARENT);
            if (nex != ex) Native.SetWindowLongInt(Handle, Native.GWL_EXSTYLE, nex);
        }

        // ============================================================ context menu foreground

        private void PrepareMenuForeground()
        {
            // Like NotifyIcon: make one of OUR top-level windows foreground so the
            // ContextMenuStrip closes when the user clicks anywhere else.  Allowed
            // because our thread just received the input event (the right click).
            try
            {
                _prevForeground = Native.GetForegroundWindow();
                if (_sink != null && _sink.Handle != IntPtr.Zero) Native.SetForegroundWindow(_sink.Handle);
            }
            catch (Exception) { }
        }

        protected override void OnContextMenuStripChanged(EventArgs e)
        {
            if (_hookedMenu != null) _hookedMenu.Closed -= OnMenuClosed;
            _hookedMenu = ContextMenuStrip;
            if (_hookedMenu != null) _hookedMenu.Closed += OnMenuClosed;
            base.OnContextMenuStripChanged(e);
        }

        private void OnMenuClosed(object sender, ToolStripDropDownClosedEventArgs e)
        {
            try
            {
                if (_sink != null && Native.GetForegroundWindow() == _sink.Handle
                    && _prevForeground != IntPtr.Zero && Native.IsWindow(_prevForeground))
                    Native.SetForegroundWindow(_prevForeground);
            }
            catch (Exception) { }
            _prevForeground = IntPtr.Zero;
        }

        // ============================================================ Desktop mode upkeep

        private void RaiseInHost()
        {
            Native.SetWindowPos(Handle, Native.HWND_TOP, 0, 0, 0, 0,
                Native.SWP_NOMOVE | Native.SWP_NOSIZE | Native.SWP_NOACTIVATE);
        }

        private void VerifyParent()
        {
            try
            {
                if (_closing || !IsHandleCreated || _active != ActiveDesktop) return;
                if (Native.IsWindow(_host) && Native.GetParent(Handle) != _host) RepairParent();
            }
            catch (Exception ex) { Log("verify parent: " + ex.Message); }
        }

        /// <summary>Something (WinForms owner logic, a shell quirk) changed our parent: put it back.</summary>
        private void RepairParent()
        {
            _parentRepairs++;
            if (_parentRepairs > 3)
            {
                BlockDesktop("parent keeps changing (repaired 3 times)");
                SafeRecreate();
                return;
            }
            Log("parent changed to 0x" + Native.GetParent(Handle).ToInt64().ToString("X") + " -> SetParent back to host");
            Native.SetParent(Handle, _host);
            if (Native.GetParent(Handle) != _host)
            {
                BlockDesktop("SetParent back to the desktop host failed, win32 error " + Marshal.GetLastWin32Error());
                SafeRecreate();
                return;
            }
            ApplyLayered();
            MoveChild();
            RaiseInHost();
        }

        private void WatchDesktop()
        {
            if (!Native.IsWindow(_host))
            {
                Log("desktop host vanished -> re-attach");
                SafeRecreate();
                return;
            }
            if (Native.GetParent(Handle) != _host)
            {
                RepairParent();
                return;
            }
            string layout;
            IntPtr cur = DesktopHost.FindIconHost(out layout);
            if (cur != IntPtr.Zero && cur != _host)
            {
                Reparent(cur, layout);
                return;
            }
            // stay above SHELLDLL_DefView (only fight the icon view, not other widgets)
            IntPtr w = Native.GetWindow(Handle, Native.GW_HWNDPREV);
            for (int i = 0; w != IntPtr.Zero && i < 64; i++)
            {
                if (DesktopHost.ClassIs(w, "SHELLDLL_DefView")) { RaiseInHost(); break; }
                w = Native.GetWindow(w, Native.GW_HWNDPREV);
            }
        }

        private void Reparent(IntPtr newHost, string layout)
        {
            string why = DesktopHost.CheckDpiCompat(newHost);
            if (why != null) { BlockDesktop(why); SafeRecreate(); return; }
            Log("SHELLDLL_DefView moved to 0x" + newHost.ToInt64().ToString("X") + " (" + layout + ") -> SetParent");
            Native.SetParent(Handle, newHost);
            int err = Marshal.GetLastWin32Error();
            if (Native.GetParent(Handle) != newHost)
            {
                BlockDesktop("SetParent to the new desktop host failed, win32 error " + err);
                SafeRecreate();
                return;
            }
            _host = newHost;
            _layout = layout;
            _parentRepairs = 0;
            ApplyLayered();
            MoveChild();
            RaiseInHost();
            SetMode("Desktop", BuildDetail());
        }

        // ============================================================ Bottom mode upkeep

        private void HookEvents()
        {
            try
            {
                if (_hookFg == IntPtr.Zero)
                    _hookFg = Native.SetWinEventHook(Native.EVENT_SYSTEM_FOREGROUND, Native.EVENT_SYSTEM_FOREGROUND,
                        IntPtr.Zero, _winEventProc, 0, 0, Native.WINEVENT_OUTOFCONTEXT);
                if (_hookMin == IntPtr.Zero)
                    _hookMin = Native.SetWinEventHook(Native.EVENT_SYSTEM_MINIMIZESTART, Native.EVENT_SYSTEM_MINIMIZEEND,
                        IntPtr.Zero, _winEventProc, 0, 0, Native.WINEVENT_OUTOFCONTEXT);
            }
            catch (Exception ex) { Log("SetWinEventHook failed: " + ex.Message); }
        }

        private void UnhookEvents()
        {
            if (_hookFg != IntPtr.Zero) { Native.UnhookWinEvent(_hookFg); _hookFg = IntPtr.Zero; }
            if (_hookMin != IntPtr.Zero) { Native.UnhookWinEvent(_hookMin); _hookMin = IntPtr.Zero; }
        }

        private void OnWinEvent(IntPtr hook, uint evt, IntPtr hwnd, int idObject, int idChild, uint thread, uint time)
        {
            try
            {
                if (_active != ActiveBottom || !IsHandleCreated) return;
                EnsureAboveDesktop(false);
                _zBurstUntil = unchecked(Environment.TickCount + 800);  // Show Desktop settles over a few frames
            }
            catch (Exception) { }
        }

        /// <summary>Keep the popup directly above the desktop host, i.e. below every app window.</summary>
        private void EnsureAboveDesktop(bool force)
        {
            if (!IsHandleCreated || _active != ActiveBottom) return;
            string layout;
            IntPtr anchor = DesktopHost.FindIconHost(out layout);
            if (anchor == IntPtr.Zero) anchor = Native.GetShellWindow();

            if ((Native.GetWindowLongInt(Handle, Native.GWL_EXSTYLE) & Native.WS_EX_TOPMOST) != 0)
                ZMove(Native.HWND_NOTOPMOST);

            if (anchor == IntPtr.Zero)
            {
                if (force) ZMove(Native.HWND_BOTTOM);
                return;
            }
            if (!force && IsDirectlyAbove(anchor)) return;
            IntPtr prev = Native.GetWindow(anchor, Native.GW_HWNDPREV);
            if (prev == Handle) return;
            if (!force && !CountZFix()) return;
            // insert-after = window just above the host  =>  we land between it and the host
            ZMove(prev == IntPtr.Zero ? Native.HWND_TOP : prev);
        }

        /// <summary>Aero Peek (hovering the show-desktop corner) hides top-level windows; stay visible.</summary>
        private void ExcludeFromPeek()
        {
            try
            {
                int on = 1;
                Native.DwmSetWindowAttribute(Handle, Native.DWMWA_EXCLUDED_FROM_PEEK, ref on, 4);
            }
            catch (Exception) { }
        }

        private void ZMove(IntPtr insertAfter)
        {
            _allowZ = true;
            try
            {
                Native.SetWindowPos(Handle, insertAfter, 0, 0, 0, 0,
                    Native.SWP_NOMOVE | Native.SWP_NOSIZE | Native.SWP_NOACTIVATE | Native.SWP_NOOWNERZORDER);
            }
            finally { _allowZ = false; }
        }

        /// <summary>Back off if something else keeps fighting for the same z slot.</summary>
        private bool CountZFix()
        {
            int now = Environment.TickCount;
            if (unchecked(now - _zFixWindowStart) > 10000) { _zFixWindowStart = now; _zFixes = 0; }
            _zFixes++;
            if (_zFixes == 40) Log("z-order fight detected (another 'on desktop' window?) - backing off");
            return _zFixes < 40 || (_zFixes % 8) == 0;
        }

        private bool IsDirectlyAbove(IntPtr anchor)
        {
            Native.RECT me;
            if (!Native.GetWindowRect(Handle, out me)) return true;
            IntPtr w = Native.GetWindow(Handle, Native.GW_HWNDNEXT);
            for (int i = 0; w != IntPtr.Zero && i < 4096; i++)
            {
                if (w == anchor) return true;
                if (Native.IsWindowVisible(w) && !DesktopHost.IsCloaked(w))
                {
                    int ex = Native.GetWindowLongInt(w, Native.GWL_EXSTYLE);
                    bool toolLike = (ex & (Native.WS_EX_TOOLWINDOW | Native.WS_EX_NOACTIVATE)) != 0;
                    Native.RECT r;
                    if (!toolLike && Native.GetWindowRect(w, out r)
                        && r.Left < me.Right && r.Right > me.Left && r.Top < me.Bottom && r.Bottom > me.Top)
                        return false;   // an app window is BELOW us -> we would cover it
                }
                w = Native.GetWindow(w, Native.GW_HWNDNEXT);
            }
            return false;   // host is above us (Show Desktop) or not found below
        }

        // ============================================================ timers + notifications

        private void OnHitTick(object sender, EventArgs e)
        {
            _hitSw.Start(); _hitCount++;
            try
            {
                if (_closing || !IsHandleCreated) return;
                UpdateClickThrough(false);
                if (_active == ActiveBottom && unchecked(Environment.TickCount - _zBurstUntil) < 0)
                    EnsureAboveDesktop(false);
            }
            catch (Exception ex) { Log("hit timer: " + ex.Message); }
            finally { _hitSw.Stop(); }
        }

        private void OnWatchTick(object sender, EventArgs e)
        {
            try
            {
                if (_closing) return;
                if (!IsHandleCreated)
                {
                    if (!_hostLost) return;
                    int waited = unchecked(Environment.TickCount - _hostLostSince);
                    string layout;
                    IntPtr h = DesktopHost.FindIconHost(out layout);
                    if ((h != IntPtr.Zero && waited > 1200) || waited > HostLostGiveUpMs)
                    {
                        _hostLost = false;
                        Log(h != IntPtr.Zero ? "Explorer is back -> re-creating the widget" : "Explorer still missing -> re-creating as Bottom");
                        CreateControl();
                        if (!IsHandleCreated) CreateHandle();
                        if (IsHandleCreated && !Native.IsWindowVisible(Handle)) Native.ShowWindow(Handle, Native.SW_SHOWNOACTIVATE);
                        ScheduleWorkAreaCheck(true);
                    }
                    return;
                }
                if (_active == ActiveDesktop) WatchDesktop();
                else if (_active == ActiveBottom)
                {
                    EnsureAboveDesktop(false);
                    // Bottom only because Explorer was not ready? try Desktop again now and then
                    if (_requested != DesktopModeRequest.Bottom && _desktopBlocked == null
                        && unchecked(Environment.TickCount - _bottomSince) > BottomRetryDesktopMs)
                    {
                        _bottomSince = Environment.TickCount;
                        string layout;
                        if (DesktopHost.FindIconHost(out layout) != IntPtr.Zero)
                        {
                            Log("desktop host available now -> switching to Desktop");
                            SafeRecreate();
                            return;
                        }
                    }
                }
                CheckWorkArea(false);
            }
            catch (Exception ex) { Log("watchdog: " + ex.Message); }
        }

        internal void NotifySystemChange()
        {
            ScheduleWorkAreaCheck(false);
            if (_active == ActiveBottom) _zBurstUntil = unchecked(Environment.TickCount + 800);
        }

        internal void NotifyExplorerRestarted()
        {
            Log("TaskbarCreated (Explorer (re)started)");
            if (_active == ActiveBottom) _bottomSince = unchecked(Environment.TickCount - BottomRetryDesktopMs + 1500);
            ScheduleWorkAreaCheck(true);
        }

        private void ScheduleWorkAreaCheck(bool force)
        {
            if (!IsHandleCreated || _closing) return;
            try
            {
                if (force) BeginInvoke(new MethodInvoker(ForceWorkAreaCheck));
                else BeginInvoke(new MethodInvoker(SoftWorkAreaCheck));
            }
            catch (Exception) { }
        }

        private void ForceWorkAreaCheck() { CheckWorkArea(true); }
        private void SoftWorkAreaCheck() { CheckWorkArea(false); }

        private void CheckWorkArea(bool force)
        {
            if (_closing) return;
            Rectangle wa = DesktopHost.GetWorkArea();
            int dpi = DesktopHost.GetPrimaryDpi();
            if (!force && wa == _lastWorkArea && dpi == _lastDpi) return;
            _lastWorkArea = wa;
            _lastDpi = dpi;
            Log("work area " + wa + " dpi " + dpi + (force ? " (refresh)" : " (changed)"));
            EventHandler h = WorkAreaChanged;
            if (h != null)
            {
                try { h(this, EventArgs.Empty); }
                catch (Exception ex) { AppendLog("WorkAreaChanged handler: " + ex.Message); }
            }
        }

        // ============================================================ log

        private void Log(string msg)
        {
            AppendLog(msg);
            EventHandler<DesktopLogEventArgs> h = LogMessage;
            if (h != null)
            {
                try { h(this, new DesktopLogEventArgs(msg)); }
                catch (Exception) { }
            }
        }

        private void AppendLog(string msg)
        {
            if (_log.Length > MaxLogChars) _log.Remove(0, _log.Length - MaxLogChars / 2);
            _log.Append(DateTime.Now.ToString("HH:mm:ss.fff")).Append(' ').Append(msg).Append("\r\n");
        }

        // ============================================================ teardown

        protected override void OnFormClosing(FormClosingEventArgs e)
        {
            base.OnFormClosing(e);
            if (!e.Cancel) _closing = true;
        }

        protected override void Dispose(bool disposing)
        {
            _closing = true;
            if (disposing)
            {
                try
                {
                    _watch.Stop(); _watch.Dispose();
                    _hit.Stop(); _hit.Dispose();
                    UnhookEvents();
                    if (_hookedMenu != null) { _hookedMenu.Closed -= OnMenuClosed; _hookedMenu = null; }
                    if (_sink != null) { _sink.DestroyHandle(); _sink = null; }
                    FreeBuffer();
                }
                catch (Exception) { }
            }
            base.Dispose(disposing);
        }
    }
}

// =====================================================================
//  KediApp.cs  -  widget'in kendisi (C# 5, ASCII)
//
//  catbar.ps1 bu kodu bir kez kucuk bir .exe olarak derler
//  (%LOCALAPPDATA%\TaskbarKedileri\TaskbarKedileri-<ozet>.exe) ve onu
//  baslatip kapanir. Boylece arka planda ~110 MB'lik PowerShell yerine
//  yalnizca bu kucuk WinForms sureci calisir. Exe baslatilamazsa ayni
//  Run() PowerShell icinden cagrilir (eski yontem, yedek).
// =====================================================================

namespace TaskbarKedileri
{
    public static class KediApp
    {
        static string _logPath;
        static Mutex _single;

        [STAThread]
        public static int Main(string[] args)
        {
            string log = args.Length > 0 ? args[0] : Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "catbar-hata.log");
            try
            {
                Application.EnableVisualStyles();
                Run(log);
                return 0;
            }
            catch (Exception ex)
            {
                Fatal(ex);
                return 1;
            }
        }

        public static void Log(string msg)
        {
            if (string.IsNullOrEmpty(_logPath)) return;
            try
            {
                File.AppendAllText(_logPath, "[" + DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss", CultureInfo.InvariantCulture)
                                   + "] [bilgi] " + msg + "\r\n", System.Text.Encoding.UTF8);
            }
            catch (Exception) { }
        }

        static void Fatal(Exception ex)
        {
            try
            {
                File.AppendAllText(_logPath, "[" + DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss", CultureInfo.InvariantCulture) + "] "
                                   + ex.GetType().Name + ": " + ex.Message + "\r\n" + ex.StackTrace + "\r\n", System.Text.Encoding.UTF8);
            }
            catch (Exception) { }
            MessageBox.Show("Kedi widget'i baslatilamadi.\r\n\r\n" + ex.Message + "\r\n\r\nAyrinti: " + _logPath, "Taskbar Kedileri");
        }

        /// <summary>Widget'i kurar ve mesaj dongusunu calistirir (Cikis'a kadar doner).</summary>
        public static void Run(string logPath)
        {
            _logPath = logPath;

            // tek kopya: iki kez cift tiklanirsa ikinci sessizce cikar
            bool created;
            _single = new Mutex(true, "Local\\TaskbarKedileri", out created);
            if (!created) { Log("Zaten calisiyor, ikinci kopya kapatildi"); return; }

            Log("Verimlilik modu: " + KediWidget.EnableEfficiencyMode() + " | surec: " + Process.GetCurrentProcess().ProcessName);

            string modeSetting = Environment.GetEnvironmentVariable("CATBAR_MODE");
            if (string.IsNullOrEmpty(modeSetting)) modeSetting = "Auto";

            bool desktopOk = false;
            try
            {
                DesktopHost.InitDpi();     // Per-Monitor-V2: ilk WorkingArea sorgusundan ve pencereden ONCE
                string info = DesktopHost.Describe();
                desktopOk = true;
                Log("DesktopHost hazir: " + info);
            }
            catch (Exception ex) { Log("DesktopHost kullanilamadi, siradan pencereye donuluyor: " + ex.Message); }

            // ---- pencere
            Form form;
            DesktopForm df = null;
            if (desktopOk)
            {
                df = new DesktopForm();
                try { df.RequestedMode = (DesktopModeRequest)Enum.Parse(typeof(DesktopModeRequest), modeSetting, true); }
                catch (Exception) { Log("Gecersiz CATBAR_MODE '" + modeSetting + "' (Auto/Desktop/Bottom) - Auto kullaniliyor"); }
                form = df;
            }
            else
            {
                form = new Form();
                form.TopMost = false;
            }
            Color key = Color.FromArgb(255, 0, 255);
            form.FormBorderStyle = FormBorderStyle.None;
            form.ShowInTaskbar = false;
            form.StartPosition = FormStartPosition.Manual;
            form.BackColor = key;
            form.TransparencyKey = key;
            form.Text = "Taskbar Kedileri";
            if (df == null)   // DesktopForm kendi tamponunu kullanir; siradan Form'da WinForms tamponu
                typeof(Control).GetProperty("DoubleBuffered", BindingFlags.Instance | BindingFlags.NonPublic).SetValue(form, true, null);

            // ---- sprite'lar + motor + cizici
            KediWidget widget;
            using (MemoryStream ms = new MemoryStream(Convert.FromBase64String(KediAssets.SheetB64)))
            using (Image sheet = Image.FromStream(ms))
            {
                Hashtable frames = new Hashtable();
                for (int i = 0; i < KediAssets.Names.Length; i++)
                    frames[KediAssets.Names[i]] = new object[] { KediAssets.Xs[i], KediAssets.Ys[i] };
                widget = new KediWidget(form, sheet, frames, KediAssets.CellW, KediAssets.CellH);
            }

            int userScale = 2;
            MethodInvoker updateBounds = delegate
            {
                Rectangle wa = desktopOk ? DesktopHost.GetWorkArea() : Screen.PrimaryScreen.WorkingArea;
                int px = desktopOk ? DesktopHost.GetPixelScale() : 1;      // %150+ DPI'da tam sayi carpan
                int scale = userScale * Math.Max(1, px);
                int h = (KediAssets.CellH + Engine.HEADROOM) * scale;
                // Bounds HER ZAMAN ekran koordinati; DesktopForm Progman/WorkerW icindeyken kendisi cevirir.
                form.Bounds = new Rectangle(wa.X, wa.Bottom - h, wa.Width, h);
                widget.SetLayout(scale, (int)Math.Floor((double)wa.Width / scale));
            };
            updateBounds();

            if (df != null)
            {
                // taskbar tasindi / boyut / otomatik gizle, cozunurluk ya da DPI degisti, Explorer yeniden basladi
                df.WorkAreaChanged += delegate { updateBounds(); };
                df.ModeChanged += delegate { Log("Masaustu modu: " + df.Mode + " | " + df.ModeDetail); };
                df.LogMessage += delegate (object s, DesktopLogEventArgs e) { Log("DesktopHost: " + e.Message); };
            }

            // ---- menu (sag tik)
            ContextMenuStrip menu = new ContextMenuStrip();
            ToolStripItem miPause = menu.Items.Add("Duraklat");
            miPause.Click += delegate
            {
                widget.Paused = !widget.Paused;
                miPause.Text = widget.Paused ? "Devam et" : "Duraklat";
            };
            menu.Items.Add("-");
            for (int z = 1; z <= 3; z++)
            {
                int zz = z;
                ToolStripItem mi = menu.Items.Add("Boyut " + z + "x");
                mi.Click += delegate { userScale = zz; updateBounds(); };
            }
            menu.Items.Add("-");
            menu.Items.Add("Sahneyi degistir").Click += delegate { widget.NextScene(); };

            if (df != null)
            {
                menu.Items.Add("-");
                ToolStripMenuItem miMode = new ToolStripMenuItem("Konum");
                ToolStripMenuItem miInfo = new ToolStripMenuItem("Aktif: ?");
                miInfo.Enabled = false;
                miMode.DropDownItems.Add(miInfo);
                string[][] modes = { new string[] { "Otomatik", "Auto" }, new string[] { "Masaustune yerlestir", "Desktop" },
                                     new string[] { "Pencerelerin altinda", "Bottom" } };
                foreach (string[] pair in modes)
                {
                    ToolStripMenuItem it = new ToolStripMenuItem(pair[0]);
                    it.Tag = pair[1];
                    it.Click += delegate (object s, EventArgs e)
                    {
                        df.RequestedMode = (DesktopModeRequest)Enum.Parse(typeof(DesktopModeRequest), (string)((ToolStripItem)s).Tag);
                    };
                    miMode.DropDownItems.Add(it);
                }
                miMode.DropDownOpening += delegate
                {
                    miInfo.Text = "Aktif: " + df.Mode;
                    foreach (ToolStripItem it in miMode.DropDownItems)
                    {
                        ToolStripMenuItem tm = it as ToolStripMenuItem;
                        if (tm != null && tm.Tag != null) tm.Checked = (string)tm.Tag == df.RequestedMode.ToString();
                    }
                };
                menu.Items.Add(miMode);
            }

            menu.Items.Add("-");
            menu.Items.Add("Cikis").Click += delegate { form.Close(); };
            form.ContextMenuStrip = menu;

            // ---- olcum (istege bagli): CATBAR_PERF=1 ise her 30 sn log'a yazar
            if (!string.IsNullOrEmpty(Environment.GetEnvironmentVariable("CATBAR_PERF")))
            {
                Process me = Process.GetCurrentProcess();
                TimeSpan cpu0 = me.TotalProcessorTime;
                DateTime t0 = DateTime.UtcNow;
                System.Windows.Forms.Timer perf = new System.Windows.Forms.Timer();
                perf.Interval = 30000;
                perf.Tick += delegate
                {
                    me.Refresh();
                    DateTime now = DateTime.UtcNow;
                    double pct = (me.TotalProcessorTime - cpu0).TotalMilliseconds / (now - t0).TotalMilliseconds * 100.0;
                    Log(string.Format(CultureInfo.InvariantCulture,
                        "PERF cpu={0:F2}% (1 cekirdek) ws={1:F1}MB ozel={2:F1}MB | {3}",
                        pct, me.WorkingSet64 / 1048576.0, me.PrivateMemorySize64 / 1048576.0, widget.Stats()));
                    cpu0 = me.TotalProcessorTime; t0 = now;
                };
                perf.Start();
            }

            // ---- dongu
            form.FormClosed += delegate { widget.Dispose(); Application.Exit(); };
            // Run(form) DEGIL: Explorer yeniden baslayinca cocuk pencereyi yok eder; formsuz
            // dongu ayakta kalir, DesktopForm penceresini yeniden kurar. "Cikis" yine Exit cagirir.
            form.Show();
            GC.Collect();
            GC.WaitForPendingFinalizers();
            Application.Run();
            GC.KeepAlive(_single);
        }
    }
}
'@

$refs = @('System.Windows.Forms', 'System.Drawing')
$exe = $null
try {
  $sha  = [System.Security.Cryptography.SHA256]::Create()
  $build = 'exe2-manifest'   # derleme ayarlari degisince onbellegi gecersiz kilmak icin
  $hash = -join ($sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($build + $KediCs))[0..7] | ForEach-Object { $_.ToString('x2') })
  $dir  = Join-Path $env:LOCALAPPDATA 'TaskbarKedileri'
  $exe  = Join-Path $dir "TaskbarKedileri-$hash.exe"
  if (-not (Test-Path $exe)) {
    [void](New-Item -ItemType Directory -Force -Path $dir)
    Get-ChildItem -Path $dir -Filter 'TaskbarKedileri-*.exe' -ErrorAction SilentlyContinue |
      ForEach-Object { try { Remove-Item $_.FullName -Force -ErrorAction Stop } catch { } }   # eski surumler
    # Uygulama bildirimi (manifest) SART: Windows 8+ uyumlulugunu bildirmeyen bir
    # surec masaustune "katmanli cocuk pencere" acamaz (Desktop modu -> Bottom'a duser).
    $manifest = Join-Path $dir 'TaskbarKedileri.manifest'
    [System.IO.File]::WriteAllText($manifest, @'
<?xml version="1.0" encoding="utf-8" standalone="yes"?>
<assembly xmlns="urn:schemas-microsoft-com:asm.v1" manifestVersion="1.0">
  <assemblyIdentity version="1.2.0.0" name="TaskbarKedileri" type="win32"/>
  <trustInfo xmlns="urn:schemas-microsoft-com:asm.v3">
    <security><requestedPrivileges><requestedExecutionLevel level="asInvoker" uiAccess="false"/></requestedPrivileges></security>
  </trustInfo>
  <compatibility xmlns="urn:schemas-microsoft-com:compatibility.v1">
    <application>
      <supportedOS Id="{8e0f7a12-bfb3-4fe8-b9a5-48fd50a15a9a}"/>
      <supportedOS Id="{1f676c76-80e1-4239-95bb-83d0f6d0da78}"/>
      <supportedOS Id="{4a2f28e3-53b9-4441-ba9c-d69d4a4a6e38}"/>
      <supportedOS Id="{35138b9a-5d96-4fbd-8e2d-a2440225f93a}"/>
    </application>
  </compatibility>
</assembly>
'@, [System.Text.Encoding]::ASCII)
    $cp = New-Object System.CodeDom.Compiler.CompilerParameters
    $cp.GenerateExecutable = $true
    $cp.GenerateInMemory   = $false
    $cp.OutputAssembly     = $exe
    $cp.CompilerOptions    = '/target:winexe /optimize+ /win32manifest:"' + $manifest + '"'
    [void]$cp.ReferencedAssemblies.AddRange([string[]]@('System.dll', 'System.Drawing.dll', 'System.Windows.Forms.dll'))
    $res  = (New-Object Microsoft.CSharp.CSharpCodeProvider).CompileAssemblyFromSource($cp, $KediCs)
    $errs = @($res.Errors | Where-Object { -not $_.IsWarning })
    if ($errs.Count -gt 0) { throw ('derleme hatasi: ' + (($errs | Select-Object -First 3 | ForEach-Object { $_.ToString() }) -join ' | ')) }
    Write-CatLog "Widget derlendi: $exe"
  }
} catch {
  Write-CatLog ('Exe derlenemedi (' + $_.Exception.Message + '), PowerShell icinde calisilacak')
  $exe = $null
}

# 1) kucuk exe olarak baslat (onerilen)
if ($exe -and (Test-Path $exe)) {
  try {
    $p = Start-Process -FilePath $exe -ArgumentList ('"' + $LogPath + '"') -PassThru
    Start-Sleep -Milliseconds 1500
    if (-not $p.HasExited -or $p.ExitCode -eq 0) { return }        # calisiyor (ya da zaten acikti)
    Write-CatLog "Exe hemen kapandi (cikis kodu $($p.ExitCode)), PowerShell icinde calisilacak"
  } catch {
    Write-CatLog ('Exe baslatilamadi (' + $_.Exception.Message + '), PowerShell icinde calisilacak')
  }
}

# 2) yedek: ayni widget bu surecte
if (-not ('TaskbarKedileri.KediApp' -as [type])) {
  if ($exe -and (Test-Path $exe)) { [void][System.Reflection.Assembly]::LoadFrom($exe) }
  else { Add-Type -TypeDefinition $KediCs -Language CSharp -ReferencedAssemblies $refs -IgnoreWarnings }
}
Remove-Variable KediCs
[System.Windows.Forms.Application]::EnableVisualStyles()
[TaskbarKedileri.KediApp]::Run($LogPath)

}
catch {
  $msg = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $($_.Exception.GetType().Name): $($_.Exception.Message)`r`n$($_.ScriptStackTrace)`r`n"
  Add-Content -Path $LogPath -Value $msg -Encoding UTF8
  Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
  [System.Windows.Forms.MessageBox]::Show("Kedi widget'i baslatilamadi.`r`n`r`n$($_.Exception.Message)`r`n`r`nAyrinti: $LogPath", 'Taskbar Kedileri') | Out-Null
}
