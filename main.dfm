object mainFrm: TmainFrm
  Left = 334
  Top = 197
  Width = 268
  Height = 346
  Caption = 'Http Screen Grabber'
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  Position = poScreenCenter
  OnCreate = FormCreate
  PixelsPerInch = 96
  TextHeight = 13
  object outBox: TMemo
    Left = 0
    Top = 79
    Width = 260
    Height = 240
    Align = alClient
    ScrollBars = ssVertical
    TabOrder = 0
  end
  object ToolBar1: TToolBar
    Left = 0
    Top = 0
    Width = 260
    Height = 79
    AutoSize = True
    ButtonHeight = 21
    ButtonWidth = 34
    Caption = 'ToolBar1'
    EdgeInner = esNone
    EdgeOuter = esNone
    Flat = True
    ShowCaptions = True
    TabOrder = 1
    Transparent = True
    object activeBtn: TToolButton
      Left = 0
      Top = 0
      Caption = 'OFF'
      ImageIndex = 0
      OnClick = activeBtnClick
    end
    object ToolButton7: TToolButton
      Left = 34
      Top = 0
      Width = 14
      Caption = 'ToolButton7'
      ImageIndex = 5
      Style = tbsSeparator
    end
    object menuBtn: TToolButton
      Left = 48
      Top = 0
      Caption = 'Menu'
      DropdownMenu = menu
      ImageIndex = 5
    end
    object ToolButton2: TToolButton
      Left = 82
      Top = 0
      Width = 8
      Caption = 'ToolButton2'
      ImageIndex = 2
      Style = tbsSeparator
    end
    object Label3: TLabel
      Left = 90
      Top = 0
      Width = 35
      Height = 21
      Caption = 'Quality '
      Layout = tlCenter
    end
    object qualitySpin: TSpinEdit
      Left = 125
      Top = 0
      Width = 37
      Height = 22
      MaxValue = 100
      MinValue = 1
      TabOrder = 2
      Value = 20
    end
    object ToolButton6: TToolButton
      Left = 162
      Top = 0
      Width = 8
      Caption = 'ToolButton6'
      ImageIndex = 5
      Style = tbsSeparator
    end
    object Label1: TLabel
      Left = 170
      Top = 0
      Width = 22
      Height = 21
      Caption = 'Port '
      Layout = tlCenter
    end
    object portBox: TEdit
      Left = 192
      Top = 0
      Width = 42
      Height = 21
      TabOrder = 0
      Text = '8000'
      OnChange = portBoxChange
    end
    object ToolButton9: TToolButton
      Left = 0
      Top = 0
      Width = 8
      Caption = 'ToolButton9'
      ImageIndex = 5
      Wrap = True
      Style = tbsSeparator
    end
    object Label2: TLabel
      Left = 0
      Top = 29
      Width = 26
      Height = 21
      Caption = 'Grab '
      Layout = tlCenter
    end
    object grabBox: TComboBox
      Left = 26
      Top = 29
      Width = 210
      Height = 21
      AutoDropDown = True
      Style = csDropDownList
      ItemHeight = 13
      TabOrder = 1
      OnDropDown = grabBoxDropDown
      OnSelect = grabBoxSelect
      Items.Strings = (
        'Full Screen'
        'Active window'
        'Clipboard'
        'Memory')
    end
    object ToolButton5: TToolButton
      Left = 0
      Top = 29
      Width = 8
      Caption = 'ToolButton5'
      ImageIndex = 4
      Wrap = True
      Style = tbsSeparator
    end
    object Label4: TLabel
      Left = 0
      Top = 58
      Width = 25
      Height = 21
      Caption = 'URL '
      Layout = tlCenter
    end
    object urlBox: TEdit
      Left = 25
      Top = 58
      Width = 210
      Height = 21
      TabOrder = 3
    end
  end
  object menu: TPopupMenu
    Left = 144
    Top = 128
    object savecfg1: TMenuItem
      Caption = 'save options'
      OnClick = savecfg1Click
    end
    object savepic1: TMenuItem
      Caption = 'save jpeg'
      OnClick = savepic1Click
    end
    object beepChk: TMenuItem
      AutoCheck = True
      Caption = 'beep on request'
    end
    object logheaderChk: TMenuItem
      Caption = 'log header'
    end
    object refresh1: TMenuItem
      Caption = 'refresh'
      object none1: TMenuItem
        AutoCheck = True
        Caption = 'none'
        Checked = True
        GroupIndex = 1
        RadioItem = True
        OnClick = none1Click
      end
      object everyminute1: TMenuItem
        AutoCheck = True
        Caption = 'every minute'
        GroupIndex = 1
        RadioItem = True
        OnClick = everyminute1Click
      end
      object every45seconds1: TMenuItem
        AutoCheck = True
        Caption = 'every 45 seconds'
        GroupIndex = 1
        RadioItem = True
        OnClick = every45seconds1Click
      end
      object every30seconds1: TMenuItem
        AutoCheck = True
        Caption = 'every 30 seconds'
        GroupIndex = 1
        RadioItem = True
        OnClick = every30seconds1Click
      end
      object every15seconds1: TMenuItem
        AutoCheck = True
        Caption = 'every 15 seconds'
        GroupIndex = 1
        RadioItem = True
        OnClick = every15seconds1Click
      end
      object everysecond1: TMenuItem
        AutoCheck = True
        Caption = 'every second'
        GroupIndex = 1
        RadioItem = True
        OnClick = everysecond1Click
      end
    end
    object logtimeChk: TMenuItem
      AutoCheck = True
      Caption = 'log time'
    end
    object logdateChk: TMenuItem
      AutoCheck = True
      Caption = 'log date'
    end
    object about1: TMenuItem
      Caption = 'about'
      OnClick = about1Click
    end
  end
end
