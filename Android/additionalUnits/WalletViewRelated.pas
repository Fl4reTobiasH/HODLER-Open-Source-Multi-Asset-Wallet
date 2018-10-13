unit WalletViewRelated;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, strUtils,
  System.Generics.Collections, System.character,
  System.DateUtils, System.Messaging,
  System.Variants, System.IOUtils,
  FMX.Types, FMX.Graphics, FMX.Controls, FMX.Forms, FMX.Dialogs, FMX.StdCtrls,
  FMX.Controls.Presentation, FMX.Styles, System.ImageList, FMX.ImgList, FMX.Ani,
  FMX.Layouts, FMX.ExtCtrls, Velthuis.BigIntegers, FMX.ScrollBox, FMX.Memo,
  FMX.Platform, System.Threading, Math, DelphiZXingQRCode,
  FMX.TabControl, System.Sensors, System.Sensors.Components, FMX.Edit,
  FMX.Clipboard, FMX.VirtualKeyBoard, JSON,
  languages,

  FMX.Media, FMX.Objects, uEncryptedZipFile, System.Zip
{$IFDEF ANDROID},
  FMX.VirtualKeyBoard.Android,
  Androidapi.JNI,
  Androidapi.JNI.GraphicsContentViewText,
  Androidapi.JNI.App,
  Androidapi.JNI.JavaTypes,
  Androidapi.Helpers,
  FMX.Platform.Android,
  Androidapi.JNI.Provider,
  Androidapi.JNI.Net,
  Androidapi.JNI.WebKit,
  Androidapi.JNI.Os,
  Androidapi.NativeActivity,
  Androidapi.JNIBridge, SystemApp
{$ENDIF},
  FMX.Menus,
  ZXing.BarcodeFormat,
  ZXing.ReadResult,
  ZXing.ScanManager, FMX.EditBox, FMX.SpinBox, FOcr, FMX.Gestures, FMX.Effects,
  FMX.Filter.Effects, System.Actions, FMX.ActnList, System.Math.Vectors,
  FMX.Controls3D, FMX.Layers3D, FMX.StdActns, FMX.MediaLibrary.Actions,
  FMX.ComboEdit;
procedure hideEmptyWallets(Sender: TObject);
procedure walletHide(Sender: TObject);
procedure ShowHistoryDetails(Sender: TObject);
procedure changeViewOrder(Sender: TObject);
procedure changeLanguage(Sender: TObject);
procedure backToBalance(Sender: TObject);
procedure chooseToken(Sender: TObject);
procedure addToken(Sender: TObject);
procedure TrySendTransaction(Sender:TObject);
procedure reloadWalletView;
procedure OpenWallet(Sender:TObject);
procedure organizeView(Sender:TObject);
procedure newCoin(Sender:TObject);
procedure CreateWallet(Sender:TObject);
procedure ShowETHWallets(Sender:TObject);
procedure synchro;
procedure SendClick(Sender:TObject);
procedure calcFeeWithSpin;
procedure calcUSDFee;
procedure sendAllFunds;
procedure importCheck;
implementation

uses uHome, misc, AccountData, base58, bech32, CurrencyConverter, SyncThr, WIF,
  Bitcoin, coinData, cryptoCurrencyData, Ethereum, secp256k1, tokenData,
  transactions, WalletStructureData, AccountRelated;
procedure sendAllFunds;
begin
with frmHome do begin
  if SendAllFundsSwitch.IsFocused then
  begin
    if SendAllFundsSwitch.IsChecked then
    begin
      wvAmount.Text := lbBalanceLong.Text;
      WVRealCurrency.Text :=
        floatToStrF(CurrencyConverter.calculate
        (strToFloatDef(lbBalanceLong.Text, 0) * CurrentCryptoCurrency.rate),
        ffFixed, 18, 2);
      FeeFromAmountSwitch.IsChecked := true;
      FeeFromAmountSwitch.Enabled := false;
    end
    else
    begin
      wvAmount.Text := BigIntegertoFloatStr(0, CurrentCryptoCurrency.decimals);
      WVRealCurrency.Text := '0.00';
      FeeFromAmountSwitch.IsChecked := false;

      FeeFromAmountSwitch.Enabled := true;
    end;
  end;
  end;
end;
procedure calcUSDFee;
var
  satb: Integer;
  curWUstr: AnsiString;
begin
with frmHome do begin
  if isTokenTransfer then
  begin
    lblFeeHeader.Text := languages.dictionary('GasPriceWEI') + ': ';
    lblFee.Text := wvFee.Text + ' ' +
      floatToStrF(CurrencyConverter.calculate(strToFloatDef(wvFee.Text,
      0) * 66666 * CurrentCryptoCurrency.rate / (1000000.0 * 1000000.0 *
      1000000.0)), ffFixed, 18, 6) + ' ' + CurrencyConverter.symbol;
  end
  else if isEthereum then
  begin
    lblFeeHeader.Text := dictionary('GasPriceWEI') + ': ';
    lblFee.Text := wvFee.Text + ' ' + AvailableCoin[CurrentCoin.coin].shortcut +
      ' = ' + floatToStrF(CurrencyConverter.calculate(strToFloatDef(wvFee.Text,
      0) * CurrentCoin.rate * 21000 / (1000000.0 * 1000000.0 * 1000000.0)),
      ffFixed, 18, 6) + ' ' + CurrencyConverter.symbol;
  end
  else
  begin
    lblFeeHeader.Text := dictionary('TransactionFee') + ': ';
    if curWU = 0 then
      curWU := 440; // 2 in 2 out default
    satb := BigInteger(StrFloatToBigInteger(wvFee.Text,
      CurrentCryptoCurrency.decimals) div curWU).asInteger;
    if (CurrentCoin.coin = 0) or (CurrentCoin.coin = 1) then
    begin
      curWUstr := ' sat/WU) ';
      satb := satb div 4;
    end
    else
      curWUstr := ' sat/b) ';

    lblFee.Text := wvFee.Text + ' (' + IntToStr(satb) + curWUstr + AvailableCoin
      [CurrentCoin.coin].shortcut + ' = ' +
      floatToStrF(CurrencyConverter.calculate(strToFloatDef(wvFee.Text,
      0) * CurrentCoin.rate), ffFixed, 18, 6) + ' ' + CurrencyConverter.symbol;
  end;
  end;
end;
procedure calcFeeWithSpin;
var
  a: BigInteger;
begin
  with frmHome do begin
  if not isEthereum then
  begin
    a := ((180 * length(CurrentAccount.aggregateUTXO(currentCoin)) +
      (34 * 2) + 12));
    curWU := a.asInteger;
    a := (a * StrFloatToBigInteger(CurrentCoin.efee[round(FeeSpin.Value) - 1],
      CurrentCoin.decimals)) div 1024;
    if (CurrentCoin.coin = 0) or (CurrentCoin.coin = 1) then
      a := a * 4;
    a := Max(a, 500);
    wvFee.Text := BigIntegertoFloatStr(a, CurrentCoin.decimals);
    // CurrentCoin.efee[round(FeeSpin.Value) - 1] ;
    lblBlockInfo.Text := dictionary('ConfirmInNext') + ' ' +
      IntToStr(round(FeeSpin.Value)) + ' ' + dictionary('Blocks');
  end
  else
    FeeSpin.Value := 1.0;
  end;
end;
procedure SendClick(Sender:TObject);
var
  amount, fee: BigInteger;
  Address: AnsiString;
begin
 with frmHome do begin
  if not isEthereum then
    fee := StrFloatToBigInteger(wvFee.Text,
      AvailableCoin[CurrentCoin.coin].decimals)
  else
  begin
    if isTokenTransfer then
      fee := BigInteger.Parse(wvFee.Text) * 66666
    else
      fee := BigInteger.Parse(wvFee.Text) * 21000;
  end;

  if (not isTokenTransfer) then
  begin
    amount := StrFloatToBigInteger(wvAmount.Text,
      AvailableCoin[CurrentCoin.coin].decimals);
    if FeeFromAmountSwitch.IsChecked then
    begin
      amount := amount - fee;
    end;

  end;

  if (isEthereum) and (isTokenTransfer) then
    amount := StrFloatToBigInteger(wvAmount.Text,
      CurrentCryptoCurrency.decimals);

  if WVsendTO.Text = '' then
  begin
    popupWindow.Create(dictionary('AddressFieldEmpty'));
    exit;
  end;
  if isBech32Address(WVsendTO.Text) and (CurrentCoin.coin <> 0) then
  begin
    popupWindow.Create(dictionary('Bech32Unsupported'));
    exit;
  end;
  if not isValidForCoin(CurrentCoin.coin, WVsendTO.Text) then
  begin

    popupWindow.Create(dictionary('WrongAddress'));
    exit;
  end;
  if { (not isEthereum) and } (not isTokenTransfer) then
    if amount + fee > (CurrentAccount.aggregateBalances(CurrentCoin).confirmed)
    then
    begin
      popupWindow.Create(dictionary('AmountExceed'));
      exit;
    end;
  Address := removeSpace(WVsendTO.Text);
  if (CurrentCryptoCurrency is TwalletInfo) and
    (TwalletInfo(CurrentCryptoCurrency).coin = 3) and isCashAddress(Address)
  then
  begin
    if isValidBCHCashAddress(Address) then
    begin

      Address := BCHCashAddrToLegacyAddr(Address);

    end
    else
    begin
      popupWindow.Create(dictionary('WrongAddress'));
      exit;
    end;
  end;
  if CurrentCoin.coin = 4 then
  begin
    if not isValidEthAddress(CurrentCoin.addr) then
    begin
      popupWindowYesNo.Create(
        procedure // yes
        begin

        end,
        procedure
        begin

          Tthread.CreateAnonymousThread(
            procedure
            begin
              Tthread.Synchronize(nil,
                procedure
                begin
                  if ValidateBitcoinAddress(Address) then
                  begin
                    prepareConfirmSendTabItem();
                    switchTab(PageControl, ConfirmSendTabItem);

                  end;
                end);

            end).Start;

        end, 'This address may be incorrect. Do you want to check again?');
      exit;
    end;
  end;

  if ValidateBitcoinAddress(Address) then
  begin
    try
      prepareConfirmSendTabItem();
    except
      on E: Exception do
      begin
        showmessage(E.Message);
        exit();
      end;
    end;

    switchTab(PageControl, ConfirmSendTabItem);
  end;
  ConfirmSendPasswordEdit.Text := '';
  end;
end;
procedure ShowETHWallets(Sender:TObject);
var
  i: Integer;
  Panel: TPanel;
  adrLabel: TLabel;
  balLabel: TLabel;
  coinIMG: TImage;
  wd: TwalletInfo;
begin

  clearVertScrollBox(frmHome.AvailableCoinsBox);

  for i := 0 to length(CurrentAccount.myCoins) - 1 do
  begin
    if CurrentAccount.myCoins[i].coin = 4 then // if ETH
    begin

      with frmHome.AvailableCoinsBox do
      begin
        wd := CurrentAccount.myCoins[i];
        Panel := TPanel.Create(frmHome.AvailableCoinsBox);
        Panel.Align := Panel.Align.alTop;
        Panel.Height := 48;
        Panel.Visible := true;
        Panel.Parent := frmHome.AvailableCoinsBox;
        Panel.TagString := CurrentAccount.myCoins[i].addr;
        Panel.OnClick := frmHome.addToken;

        adrLabel := TLabel.Create(frmHome.AvailableCoinsBox);
        adrLabel.StyledSettings := adrLabel.StyledSettings -
          [TStyledSetting.Size];
        adrLabel.TextSettings.Font.Size := dashBoardFontSize;

        adrLabel.Parent := Panel;
        adrLabel.TagString := CurrentAccount.myCoins[i].addr;

        if wd.description = '' then
        begin
          adrLabel.Text := AvailableCoin[wd.coin].displayName + ' (' +
            AvailableCoin[wd.coin].shortcut + ')';
        end
        else
        begin

          adrLabel.Text := wd.description;
        end;
        adrLabel.Visible := true;
        adrLabel.Width := 500;
        adrLabel.Height := 48;
        adrLabel.Position.X := 52;
        adrLabel.Position.Y := 0;
        adrLabel.OnClick := frmHome.addToken;

        balLabel := TLabel.Create(frmHome.WalletList);
        balLabel.StyledSettings := balLabel.StyledSettings -
          [TStyledSetting.Size];
        balLabel.TextSettings.Font.Size := 12;
        balLabel.Parent := Panel;
        balLabel.TagString := CurrentAccount.myCoins[i].addr;
        balLabel.Text := CurrentAccount.myCoins[i].addr;

        balLabel.TextSettings.HorzAlign := TTextAlign.center;
        balLabel.Visible := true;
        balLabel.Width := 500;
        balLabel.Height := 14;
        balLabel.Align := TAlignLayout.Bottom;
        balLabel.OnClick := frmHome.addToken;

        coinIMG := TImage.Create(frmHome.AvailableCoinsBox);
        coinIMG.Parent := Panel;

        coinIMG.Bitmap := getCoinIcon(wd.coin);

        coinIMG.Height := 32.0;
        coinIMG.Width := 50;
        coinIMG.Position.X := 4;
        coinIMG.Position.Y := 8;
        coinIMG.OnClick := frmHome.addToken;
        coinIMG.TagString := CurrentAccount.myCoins[i].addr;
      end;

    end;

  end;
end;
procedure synchro;
var

  aTask: ITask;
begin
  if (frmHome.PageControl.ActiveTab = frmHome.walletView) then
  begin
    SynchronizeCryptoCurrency(CurrentCryptoCurrency);
    reloadWalletView;
    exit;
  end;
  if (SyncBalanceThr <> nil) then
  begin
    if SyncBalanceThr.Finished then
    begin

      SyncBalanceThr.DisposeOf;
      SyncBalanceThr := nil;
      SyncBalanceThr := SynchronizeBalanceThread.Create();

    end
    else if SyncBalanceThr.TimeFromStart() > 1.0 / 1040.0 then
    begin

      SyncBalanceThr.Terminate;
      SyncBalanceThr.WaitFor;
      SyncBalanceThr.DisposeOf;
      SyncBalanceThr := nil;
      SyncBalanceThr := SynchronizeBalanceThread.Create();

    end;
  end;

  if SyncHistoryThr <> nil then
  begin

    if SyncHistoryThr.Finished then
    begin
      SyncHistoryThr.DisposeOf;
      SyncHistoryThr := nil;
      SyncHistoryThr := SynchronizeHistoryThread.Create();
    end
    else if SyncHistoryThr.TimeFromStart() > 1.0 / 1040.0 then
    begin

      SyncHistoryThr.Terminate;
      SyncHistoryThr.WaitFor;
      SyncHistoryThr.DisposeOf;
      SyncHistoryThr := nil;
      SyncHistoryThr := SynchronizeHistoryThread.Create();

    end;

  end;

end;
procedure CreateWallet(Sender:TObject);
var
  alphaStr: AnsiString;
  c: Char;
  num, low, up: Boolean;
  i: Integer;
begin

  num := false;
  low := false;
  up := false;
  with frmHome do begin
  if pass.Text <> retypePass.Text then
  begin
    passwordMessage.Text := dictionary('PasswordNotMatch');
    exit;
  end;
  if pass.Text.length < 8 then
  begin

    popupWindow.Create(dictionary('PasswordShort'));
    exit();

  end
  else
  begin

    for c in pass.Text do
    begin
      if isNumber(c) then
        num := true;
      if IsUpper(c) then
        up := true;
      if IsLower(c) then
        low := true;
    end;
    if not(num and up and low) then
    begin
      popupWindow.Create(dictionary('PasswordShort'));
      exit();

    end;

  end;

  if (AccountNameEdit.Text = '') or (length(AccountNameEdit.Text) < 3) then
  begin
    popupWindow.Create(dictionary('AccountNameTooShort'));
    exit();
  end;

  for i := 0 to length(AccountsNames) - 1 do
  begin

    if AccountsNames[i] = AccountNameEdit.Text then
    begin
      popupWindow.Create(dictionary('AccountNameOccupied'));
      exit();
    end;

  end;

  alphaStr := dictionary('AlphaVersionWarning');

  popupWindowYesNo.Create(
    procedure
    begin

      Tthread.CreateAnonymousThread(
        procedure
        begin
          Tthread.Synchronize(nil,
            procedure
            begin

              procCreateWallet(nil);

            end);
        end).Start;

    end,
    procedure
    begin
    end, alphaStr);
    end;
end;
procedure newCoin(Sender:TObject);
begin
  Tthread.CreateAnonymousThread(
    procedure
    var
      MasterSeed, tced: AnsiString;
      walletInfo: TwalletInfo;
      arr: array of Integer;
      wd: TwalletInfo;
      i: Integer;
      newID: Integer;
    var
      ts: TStringList;
      path: AnsiString;
      out : AnsiString;
      isCompressed: Boolean;
      WData: WIFAddressData;
      pub: AnsiString;
    begin

      i := 0;
      with frmHome do begin
      tced := TCA(NewCoinDescriptionPassEdit.Text);
      // NewCoinDescriptionPassEdit.Text := '';
      MasterSeed := SpeckDecrypt(tced, CurrentAccount.EncryptedMasterSeed);
      if not isHex(MasterSeed) then
      begin

        Tthread.Synchronize(nil,
          procedure
          begin
            popupWindow.Create(dictionary('FailedToDecrypt'));
          end);

        exit;
      end;

      if not Switch1.IsChecked then
      begin

        SetLength(arr, CurrentAccount.countWalletBy(newcoinID));
        for wd in CurrentAccount.myCoins do
        begin
          if wd.coin = newcoinID then
          begin
            arr[i] := wd.X;
            inc(i);
          end;
        end;
        newID := i;
        for i := 0 to length(arr) - 1 do
        begin
          if arr[i] <> i then
          begin
            newID := i;
            break;
          end;
        end;

        if OwnXCheckBox.IsChecked then
          newID := strtoint(OwnXEdit.Text);

        walletInfo := coindata.createCoin(newcoinID, newID, 0, MasterSeed,
          NewCoinDescriptionEdit.Text);

        CurrentAccount.AddCoin(walletInfo);
        CreatePanel(walletInfo);
        MasterSeed := '';

        switchTab(PageControl, TTabItem(frmHome.FindComponent('dashbrd')));
      end
      else
      begin

        if isHex(WIFEdit.Text) then
        begin

          APICheckCompressed(Sender);

          if (length(WIFEdit.Text) = 64) then
          begin

            Tthread.Synchronize(nil,
              procedure
              begin
                if not(HexPrivKeyCompressedRadioButton.IsChecked or
                  HexPrivKeyNotCompressedRadioButton.IsChecked) then
                  exit;
                out := WIFEdit.Text;
                if HexPrivKeyCompressedRadioButton.IsChecked then
                  isCompressed := true
                else if HexPrivKeyNotCompressedRadioButton.IsChecked then
                  isCompressed := false
                else
                  raise Exception.Create('compression not defined');
              end);

          end
          else
          begin

            Tthread.Synchronize(nil,
              procedure
              begin
                popupWindow.Create('Private Key must have 64 characters');
              end);

            exit;
          end;

        end
        else
        begin
          if WIFEdit.Text <> PrivKeyToWIF(wifToPrivKey(WIFEdit.Text)) then
          begin

            Tthread.Synchronize(nil,
              procedure
              begin
                popupWindow.Create('Wrong WIF');
              end);

            exit;
          end;
          WData := wifToPrivKey(WIFEdit.Text);
          isCompressed := WData.isCompressed;
          out := WData.PrivKey;
        end;

        {
          else
        }

        pub := secp256k1_get_public(out , not isCompressed);
        if newcoinID = 4 then
        begin

          wd := TwalletInfo.Create(newcoinID, -1, -1,
            Ethereum_PublicAddrToWallet(pub), NewCoinDescriptionEdit.Text);
          wd.pub := pub;
          wd.EncryptedPrivKey := speckEncrypt((TCA(MasterSeed)), out);
          wd.isCompressed := isCompressed;
        end
        else
        begin
          wd := TwalletInfo.Create(newcoinID, -1, -1,
            Bitcoin_PublicAddrToWallet(pub, AvailableCoin[newcoinID].p2pk),
            NewCoinDescriptionEdit.Text);
          wd.pub := pub;
          wd.EncryptedPrivKey := speckEncrypt((TCA(MasterSeed)), out);
          wd.isCompressed := isCompressed;

        end;

        Tthread.Synchronize(nil,
          procedure
          begin
            CurrentAccount.AddCoin(wd);
            CreatePanel(wd);
          end);

        MasterSeed := '';

        if newcoinID = 4 then
        begin
          SearchTokens(wd.addr);
        end;
        Tthread.Synchronize(nil,
          procedure
          begin
            switchTab(PageControl, TTabItem(frmHome.FindComponent('dashbrd')));
          end);

      end;
      Tthread.Synchronize(nil,
        procedure
        begin
          btnSyncClick(nil);
        end);
     end;
    end).Start();

end;
procedure organizeView(Sender:TObject);
var
  Panel: TPanel;
  fmxObj, child, temp: TfmxObject;

  Button: TButton;
  i: Integer;

begin
 with frmHome do begin
  vibrate(100);
  clearVertScrollBox(OrganizeList);
  for i := 0 to WalletList.Content.ChildrenCount - 1 do
  begin
    fmxObj := WalletList.Content.Children[i];

    Panel := TPanel.Create(frmHome.OrganizeList);
    Panel.Align := TAlignLayout.Top;
    Panel.Position.Y := TPanel(fmxObj).Position.Y - 1;
    Panel.Height := 48;
    Panel.Visible := true;
    Panel.Parent := frmHome.OrganizeList;
    Panel.TagObject := fmxObj.TagObject;
    Panel.Touch.InteractiveGestures := [TInteractiveGesture.LongTap];

{$IFDEF ANDROID}
    Panel.OnGesture := frmHome.PanelDragStart;
{$ELSE}
    Panel.OnMouseDown := frmHome.PanelDragStart;
{$ENDIF}
    for child in fmxObj.Children do
    begin
      if child.TagString <> 'balance' then
        temp := child.Clone(Panel);
      temp.Parent := Panel;

    end;
    Button := TButton.Create(Panel);
    Button.Width := Panel.Height;
    Button.Align := TAlignLayout.MostRight;
    Button.Text := 'X';
    Button.Visible := true;
    Button.Parent := Panel;
    Button.OnClick := hideWallet;
  end;

  OrganizeList.Repaint;
  switchTab(PageControl, TTabItem(frmHome.FindComponent('dashbrd')));
  DeleteAccountLayout.Visible := true;
  Layout1.Visible := false;

  SearchInDashBrdButton.Visible := false;
  NewCryptoLayout.Visible := false;
  WalletList.Visible := false;
  OrganizeList.Visible := true;
  BackToBalanceViewLayout.Visible := true;
  btnSync.Visible := false;
  end;
end;

procedure OpenWallet(Sender:TObject);
var
  wd: TwalletInfo;
  a: BigInteger;
begin
  lastHistCC:=10;
  CurrentCryptoCurrency := CryptoCurrency(TfmxObject(Sender).TagObject);
  reloadWalletView;
with frmHome do begin
  if isEthereum or isTokenTransfer then
  begin

    LayoutPerByte.Visible:=false;
    YAddresses.Visible := false;
    btnNewAddress.Visible := false;
    btnPrevAddress.Visible := false;
    lblFeeHeader.Text := dictionary('GasPriceWEI') + ':';
    lblFee.Text := '';
    wvFee.Text := CurrentCoin.efee[0];

    if isTokenTransfer then
    begin
      lblFee.Text := wvFee.Text + '  = ' +
        floatToStrF(frmHome.CurrencyConverter.calculate(strToFloatDef(wvFee.Text,
        0) * 66666 * CurrentCryptoCurrency.rate / (1000000.0 * 1000000.0 *
        1000000.0)), ffFixed, 18, 6) + ' ' + frmHome.CurrencyConverter.symbol;
    end;

  end
  else
  begin

    LayoutPerByte.Visible:=true;
    YAddresses.Visible := true;
    btnNewAddress.Visible := true;
    btnPrevAddress.Visible := true;
    lblFeeHeader.Text := dictionary('TransactionFee') + ':';
    lblFee.Text := '0.00 ' + CurrentCryptoCurrency.shortcut;
    wvFee.Text := CurrentCoin.efee[round(FeeSpin.Value) - 1];
  end;
  if wvFee.Text = '' then
    wvFee.Text := '0';

  wvAmount.Text := BigIntegertoFloatStr(0, CurrentCryptoCurrency.decimals);
  ReceiveValue.Text := BigIntegertoFloatStr(0, CurrentCryptoCurrency.decimals);
  ReceiveAmountRealCurrency.Text := '0.00';
  WVRealCurrency.Text := floatToStrF(strToFloatDef(wvAmount.Text, 0) *
    CurrentCryptoCurrency.rate, ffFixed, 15, 2);
  ShortcutValetInfoImage.Bitmap := CurrentCryptoCurrency.getIcon();
  wvGFX.Bitmap := CurrentCryptoCurrency.getIcon();

  lblCoinShort.Text := CurrentCryptoCurrency.shortcut + '';
  lblReceiveCoinShort.Text := CurrentCryptoCurrency.shortcut + '';
  QRChangeTimerTimer(nil);
  receiveAddress.Text := cutEveryNChar(4, CurrentCryptoCurrency.addr);

  WVsendTO.Text := '';
  SendAllFundsSwitch.IsChecked := false;
  FeeFromAmountSwitch.IsChecked := false;
  FeeFromAmountLayout.Visible := not isTokenTransfer;
  if isEthereum or isTokenTransfer then
  begin

    lblBlockInfo.Visible := false;
    FeeSpin.Visible := false;
    // FeeSpin.Opacity := 0;
    FeeSpin.Enabled := false;

  end
  else
  begin

    lblBlockInfo.Visible := true;
    FeeSpin.Visible := true;
    FeeSpin.Enabled := true;
    // FeeSpin.Opacity := 1;

  end;
  if CurrentCryptoCurrency is TwalletInfo then
  begin

    if (TwalletInfo(CurrentCryptoCurrency).coin = 0) then
      AddressTypelayout.Visible := true
    else
      AddressTypelayout.Visible := false;

    if (TwalletInfo(CurrentCryptoCurrency).X = -1) and
      (TwalletInfo(CurrentCryptoCurrency).Y = -1) and
      (TwalletInfo(CurrentCryptoCurrency).isCompressed = false) then
      AddressTypelayout.Visible := false;

    if TwalletInfo(CurrentCryptoCurrency).coin = 3 then
      BCHAddressesLayout.Visible := true
    else
      BCHAddressesLayout.Visible := false;

  end
  else
  begin
    AddressTypelayout.Visible := false;
    BCHAddressesLayout.Visible := false;
  end;
  if (CurrentCryptoCurrency is TwalletInfo) and
    (TwalletInfo(CurrentCryptoCurrency).coin = 4) then
    SearchTokenButton.Visible := true
  else
    SearchTokenButton.Visible := false;

  if not isEthereum then
  begin

    a := ((180 * length(TwalletInfo(CurrentCryptoCurrency).UTXO) +
      (34 * 2) + 12));
    curWU := a.asInteger;
    a := (a * StrFloatToBigInteger(CurrentCoin.efee[round(FeeSpin.Value) - 1],
      CurrentCoin.decimals)) div 1024;
    if (CurrentCoin.coin = 0) or (CurrentCoin.coin = 1) then
      a := a * 4;
    a := Max(a, 500);
    wvFee.Text := BigIntegertoFloatStr(a, CurrentCoin.decimals);
    // CurrentCoin.efee[round(FeeSpin.Value) - 1] ;
    lblBlockInfo.Text := dictionary('ConfirmInNext') + ' ' +
      IntToStr(round(FeeSpin.Value)) + ' ' + dictionary('Blocks');
  end;

  // changeYbutton.Text := 'Change address (' + intToStr(CurrentCoin.x) +','+inttoStr(CurrentCoin.y) + ')';
  if PageControl.ActiveTab = TTabItem(frmHome.FindComponent('dashbrd')) then
    WVTabControl.ActiveTab := WVBalance;
end;
end;
procedure reloadWalletView;
var
  wd: TwalletInfo;
  a: BigInteger;
  cc: CryptoCurrency;
  sumConfirmed, sumUnconfirmed: BigInteger;
  SumFiat: Double;
begin

  with frmHome do
  begin

    isTokenTransfer := CurrentCryptoCurrency is Token;

    if isTokenTransfer then
    begin
      for wd in CurrentAccount.myCoins do
        if wd.addr = CurrentCryptoCurrency.addr then
        begin
          CurrentCoin := wd;
          break;
        end;
    end
    else
      CurrentCoin := TwalletInfo(CurrentCryptoCurrency);

    createHistoryList(CurrentCryptoCurrency,0,lastHistCC);

    frmHome.wvAddress.Text := CurrentCryptoCurrency.addr;

    if (TwalletInfo(CurrentCryptoCurrency).coin <> 4) and (not isTokenTransfer)
    then
    begin
      sumConfirmed := 0;
      sumUnconfirmed := 0;
      SumFiat := 0;
      for cc in CurrentAccount.getWalletWithX(CurrentCoin.X,
        CurrentCoin.coin) do
      begin
        sumConfirmed := sumConfirmed + cc.confirmed;
        sumUnconfirmed := sumUnconfirmed + cc.unconfirmed;
        SumFiat := SumFiat + cc.getFiat();
      end;

      lbBalance.Text := bigintegerbeautifulStr(sumConfirmed,
        CurrentCryptoCurrency.decimals);
      lbBalanceLong.Text := BigIntegertoFloatStr(sumConfirmed,
        CurrentCryptoCurrency.decimals);
      lblFiat.Text := floatToStrF(SumFiat, ffFixed, 15, 2);

      TopInfoConfirmedValue.Text := ' ' + BigIntegertoFloatStr(sumConfirmed,
        CurrentCryptoCurrency.decimals);
      TopInfoUnconfirmedValue.Text := ' ' + BigIntegertoFloatStr(sumUnconfirmed,
        CurrentCryptoCurrency.decimals);

    end
    else
    begin
      lbBalance.Text := bigintegerbeautifulStr(CurrentCryptoCurrency.confirmed,
        CurrentCryptoCurrency.decimals);

      lbBalanceLong.Text := BigIntegertoFloatStr
        (CurrentCryptoCurrency.confirmed, CurrentCryptoCurrency.decimals);

      lblFiat.Text := floatToStrF(CurrentCryptoCurrency.getFiat(),
        ffFixed, 15, 2);

      TopInfoConfirmedValue.Text := ' ' + BigIntegertoFloatStr
        (CurrentCryptoCurrency.confirmed, CurrentCryptoCurrency.decimals);
      TopInfoUnconfirmedValue.Text := ' ' + BigIntegertoFloatStr
        (CurrentCryptoCurrency.unconfirmed, CurrentCryptoCurrency.decimals);
    end;

  end;
end;

procedure TrySendTransaction(Sender:TObject);
var
  MasterSeed, tced, Address, CashAddr: AnsiString;
var
  amount, fee, tempFee: BigInteger;
begin
 with frmHome do begin
  tced := TCA(ConfirmSendPasswordEdit.Text);
  ConfirmSendPasswordEdit.Text := '';
  MasterSeed := SpeckDecrypt(tced, CurrentAccount.EncryptedMasterSeed);
  if not isHex(MasterSeed) then
  begin
    popupWindow.Create(dictionary('FailedToDecrypt'));
    exit;
  end;

  if not isEthereum then
  begin
    fee := StrFloatToBigInteger(wvFee.Text, AvailableCoin[CurrentCoin.coin]
      .decimals);
    tempFee := fee;
  end
  else
  begin
    fee := BigInteger.Parse(wvFee.Text);

    if isTokenTransfer then
      tempFee := BigInteger.Parse(wvFee.Text) * 66666
    else
      tempFee := BigInteger.Parse(wvFee.Text) * 21000;
  end;
  if (not isTokenTransfer) then
  begin
    amount := StrFloatToBigInteger(wvAmount.Text,
      AvailableCoin[CurrentCoin.coin].decimals);
    if FeeFromAmountSwitch.IsChecked then
    begin
      amount := amount - tempFee;
    end;

  end;

  if (isEthereum) and (isTokenTransfer) then
    amount := StrFloatToBigInteger(wvAmount.Text,
      CurrentCryptoCurrency.decimals);
  if { (not isEthereum) and } (not isTokenTransfer) then
    if amount + tempFee > (CurrentAccount.aggregateBalances(CurrentCoin)
      .confirmed) then
    begin
      popupWindow.Create(dictionary('AmountExceed'));
      exit;
    end;

  if ((amount) = 0) or ((fee) = 0) then
  begin
    popupWindowOK.Create(
      procedure
      begin

        Tthread.CreateAnonymousThread(
          procedure
          begin
            switchTab(PageControl, walletView);
          end).Start;

      end, dictionary('InvalidValues'));

    exit
  end;

  Address := removeSpace(WVsendTO.Text);

  if (CurrentCryptoCurrency is TwalletInfo) and
    (TwalletInfo(CurrentCryptoCurrency).coin = 3) then
  begin
    CashAddr := StringReplace(LowerCase(Address), 'bitcoincash:', '',
      [rfReplaceAll]);
    if (LeftStr(CashAddr, 1) = 'q') or (LeftStr(CashAddr, 1) = 'p') then
    begin
      try
        Address := BCHCashAddrToLegacyAddr(Address);
      except
        on E: Exception do
        begin
          showmessage('Wrong bech32 address');
          exit;
        end;
      end;
    end;
  end;

  Tthread.CreateAnonymousThread(
    procedure
    var
      ans: AnsiString;
    begin

      Tthread.Synchronize(nil,
        procedure
        begin
          TransactionWaitForSendAniIndicator.Visible := true;
          TransactionWaitForSendAniIndicator.Enabled := true;
          TransactionWaitForSendDetailsLabel.Visible := true;
          TransactionWaitForSendDetailsLabel.Text :=
            'Sending... It may take a few seconds';
          TransactionWaitForSendLinkLabel.Visible := false;

          switchTab(PageControl, TransactionWaitForSend);
        end);

      ans := sendCoinsTO(CurrentCoin, Address, amount, fee, MasterSeed,
        AvailableCoin[CurrentCoin.coin].name);

      SynchronizeCryptoCurrency(CurrentCryptoCurrency);

      Tthread.Synchronize(nil,
        procedure
        var
          ts: TStringList;
          i: Integer;
        begin
          TransactionWaitForSendAniIndicator.Visible := false;
          TransactionWaitForSendAniIndicator.Enabled := false;
          TransactionWaitForSendDetailsLabel.Visible := false;
          TransactionWaitForSendLinkLabel.Visible := true;
          if LeftStr(ans, length('Transaction sent')) = 'Transaction sent' then
          begin
            SynchronizeCryptoCurrency(CurrentCryptoCurrency);
            TransactionWaitForSendLinkLabel.Text :=
              'Click here to see details in Explorer';
            TransactionWaitForSendDetailsLabel.Text := 'Transaction sent';

            StringReplace(ans, #$A, ' ', [rfReplaceAll]);
            ts := SplitString(ans, ' ');
            TransactionWaitForSendLinkLabel.TagString :=
              getURLToExplorer(CurrentCoin.coin, ts[ts.Count - 1]);
            TransactionWaitForSendLinkLabel.Text :=
              TransactionWaitForSendLinkLabel.TagString;
            ts.free;
            TransactionWaitForSendDetailsLabel.Visible := true;
            TransactionWaitForSendLinkLabel.Visible := true;
          end
          else
          begin
            TransactionWaitForSendDetailsLabel.Visible := true;
            TransactionWaitForSendLinkLabel.Visible := false;
            ts := SplitString(ans, #$A);
            TransactionWaitForSendDetailsLabel.Text := ts[0];
            for i := 1 to ts.Count - 1 do
              if ts[i] <> '' then
              begin
                TransactionWaitForSendDetailsLabel.Text :=
                  TransactionWaitForSendDetailsLabel.Text + #13#10 +
                  'Error: ' + ts[i];
                break;
              end;

            ts.free;
          end;
        end);

    end).Start;
    end;
end;
procedure addToken(Sender: TObject);
var
  Panel: TPanel;
  coinName: TLabel;
  coinIMG: TImage;
  i: Integer;
begin
  // save wallet address for later use
  // wallet address is used to create token
  walletAddressForNewToken := TfmxObject(Sender).TagString;

  clearVertScrollBox(frmHome.AvailableTokensBox);

  for i := 0 to length(Token.availableToken) - 1 do
  begin

    with frmHome.AvailableTokensBox do
    begin
      Panel := TPanel.Create(frmHome.AvailableTokensBox);
      Panel.Align := Panel.Align.alTop;
      Panel.Height := 48;
      Panel.Visible := true;
      Panel.Tag := i;
      Panel.Parent := frmHome.AvailableTokensBox;
      Panel.OnClick := frmHome.choseTokenClick;

      coinName := TLabel.Create(frmHome.AvailableTokensBox);
      coinName.Parent := Panel;
      coinName.Text := Token.availableToken[i].name;
      coinName.Visible := true;
      coinName.Width := 500;
      coinName.Position.X := 52;
      coinName.Position.Y := 16;
      coinName.Tag := i;
      coinName.OnClick := frmHome.choseTokenClick;

      coinIMG := TImage.Create(frmHome.AvailableTokensBox);
      coinIMG.Parent := Panel;
      coinIMG.Bitmap := frmHome.TokenIcons.Source[i].MultiResBitmap[0].Bitmap;

      coinIMG.Height := 32.0;
      coinIMG.Width := 50;
      coinIMG.Position.X := 4;
      coinIMG.Position.Y := 8;
      coinIMG.OnClick := frmHome.choseTokenClick;
      coinIMG.Tag := i;

    end;
  end;
end;
procedure chooseToken(Sender: TObject);
var
  t: Token;
  popup: TPopup;
  Panel: TPanel;
  mess: popupWindow;
begin
  for t in CurrentAccount.myTokens do
  begin

    if (t.addr = walletAddressForNewToken) and
      (t.id = (TComponent(Sender).Tag + 10000)) then
    begin

      mess := popupWindow.Create(dictionary('TokenExist'));

      exit;
    end;

  end;

  t := Token.Create(TComponent(Sender).Tag, walletAddressForNewToken);

  t.idInWallet := length(CurrentAccount.myTokens) + 10000;

  CurrentAccount.addToken(t);
  CreatePanel(t);
end;

procedure backToBalance(Sender: TObject);
var
  fmxObj: TfmxObject;
  i: Integer;
begin
  with frmHome do
  begin
    for i := 0 to OrganizeList.Content.ChildrenCount - 1 do
    begin
      fmxObj := OrganizeList.Content.Children[i];
      CryptoCurrency(fmxObj.TagObject).orderInWallet :=
        round(TPanel(fmxObj).Position.Y);
    end;

    syncTimer.Enabled := false;

    if (SyncBalanceThr <> nil) and (SyncBalanceThr.Finished = false) then
    begin
      try
        SyncBalanceThr.Terminate();
      except
        on E: Exception do
        begin

        end;
      end;
    end;

    if (SyncHistoryThr <> nil) and (SyncHistoryThr.Finished = false) then
    begin

      try
        SyncHistoryThr.Terminate();
      except
        on E: Exception do
        begin

        end;
      end;

    end;

    CurrentAccount.SaveFiles();
    clearVertScrollBox(WalletList);
    lastClosedAccount := CurrentAccount.name;
    refreshWalletDat();
    TLabel(frmHome.FindComponent('globalBalance')).Text := '0.00';
    FormShow(nil);

    syncTimer.Enabled := true;

    if SyncBalanceThr.Finished then
    begin

      SyncBalanceThr.DisposeOf;
      SyncBalanceThr := nil;
      SyncBalanceThr := SynchronizeBalanceThread.Create();

    end;

    if SyncHistoryThr.Finished then
    begin
      SyncHistoryThr.DisposeOf;
      SyncHistoryThr := nil;
      SyncHistoryThr := SynchronizeHistoryThread.Create();
    end;

    closeOrganizeView(nil);
  end;
end;

procedure changeLanguage(Sender: TObject);
var
  Data: WideString;
begin
  with frmHome do
  begin
    WelcomeTabLanguageBox.ItemIndex := TPopupBox(Sender).ItemIndex;
    LanguageBox.ItemIndex := TPopupBox(Sender).ItemIndex;

    loadDictionary(loadLanguageFile(TPopupBox(Sender).Items[TPopupBox(Sender)
      .ItemIndex]));
    refreshComponentText();
    if LanguageBox.IsFocused or WelcomeTabLanguageBox.IsFocused then
      refreshWalletDat();
  end;
end;

procedure changeViewOrder(Sender: TObject);
var
  i, j: Integer;
  swapFlag, rep: Boolean;
  temp: Single;
  function compLex(a, b: CryptoCurrency): Integer;
  var
    adesc, bdesc: AnsiString;
  begin
    if a.description = '' then
      adesc := a.name
    else
      adesc := a.description;

    if b.description = '' then
      bdesc := b.name
    else
      bdesc := b.description;

    if adesc = bdesc then
      exit(0);
    if adesc > bdesc then
      exit(1);
    exit(-1);

  end;

  function compVal(a, b: CryptoCurrency): Integer;
  var
    adesc, bdesc: AnsiString;
  begin

    if a.getFiat < b.getFiat then
      exit(-1);
    if a.getFiat > b.getFiat then
      exit(1);
    if a.confirmed > b.confirmed then
      exit(1);
    if a.confirmed < b.confirmed then
      exit(-1);
    exit(0);
  end;
  function compAmount(a, b: CryptoCurrency): Integer;
  var
    adesc, bdesc: AnsiString;
  begin

    if a.confirmed > b.confirmed then
      exit(1);
    if a.confirmed < b.confirmed then
      exit(-1);
    exit(0);
  end;

begin
  with frmHome do
  begin
    rep := true;
    while (rep) do
    begin
      rep := false;
      for i := 0 to OrganizeList.Content.ChildrenCount - 1 do
      begin

        for j := 0 to OrganizeList.Content.ChildrenCount - 1 do
        begin
          swapFlag := false;

          case PopupBox1.ItemIndex of

            0:
              if (compLex(CryptoCurrency(OrganizeList.Content.Children[i]
                .TagObject), CryptoCurrency(OrganizeList.Content.Children[j]
                .TagObject)) > 0) and
                (TPanel(OrganizeList.Content.Children[i]).Position.Y <
                TPanel(OrganizeList.Content.Children[j]).Position.Y) then
                swapFlag := true;

            1:
              if (compVal(CryptoCurrency(OrganizeList.Content.Children[i]
                .TagObject), CryptoCurrency(OrganizeList.Content.Children[j]
                .TagObject)) > 0) and
                (TPanel(OrganizeList.Content.Children[i]).Position.Y >
                TPanel(OrganizeList.Content.Children[j]).Position.Y) then
                swapFlag := true;

            2:
              if (compAmount(CryptoCurrency(OrganizeList.Content.Children[i]
                .TagObject), CryptoCurrency(OrganizeList.Content.Children[j]
                .TagObject)) > 0) and
                (TPanel(OrganizeList.Content.Children[i]).Position.Y >
                TPanel(OrganizeList.Content.Children[j]).Position.Y) then
                swapFlag := true;

          end;

          if swapFlag then
          begin

            temp := TPanel(OrganizeList.Content.Children[i]).Position.Y;
            TPanel(OrganizeList.Content.Children[i]).Position.Y :=
              TPanel(OrganizeList.Content.Children[j]).Position.Y - 1;
            TPanel(OrganizeList.Content.Children[j]).Position.Y := temp - 1;

            if (i = 8) and (j = 11) then
            begin
              compLex(CryptoCurrency(OrganizeList.Content.Children[i]
                .TagObject), CryptoCurrency(OrganizeList.Content.Children[j]
                .TagObject));
            end;

            rep := true;

          end;

        end;

      end

    end;
  end;
end;

procedure hideEmptyWallets(Sender: TObject);
var
  Panel: TPanel;
  cc: CryptoCurrency;
  tempBalances: TBalances;
  i: Integer;
begin
  with frmHome do
  begin
    for i := 0 to WalletList.Content.ChildrenCount - 1 do
    begin

      Panel := TPanel(WalletList.Content.Children[i]);
      cc := CryptoCurrency(Panel.TagObject);

      if cc is TWalletInfo then
      begin

        if TWalletInfo(cc).coin = 4 then
        begin

          Panel.Visible := (cc.confirmed + cc.unconfirmed > 0);

        end
        else
        begin
          tempBalances := CurrentAccount.aggregateBalances(TWalletInfo(cc));
          Panel.Visible :=
            (tempBalances.confirmed + tempBalances.unconfirmed > 0);

        end;

      end
      else
      begin

        Panel.Visible := (cc.confirmed + cc.unconfirmed > 0);

      end;

      Panel.Visible :=
        (Panel.Visible or (not HideZeroWalletsCheckBox.IsChecked));

    end;
    refreshOrderInDashBrd();
  end;
end;

procedure ShowHistoryDetails(Sender: TObject);
var
  th: transactionHistory;
  fmxObject: TfmxObject;
  i: Integer;
  Panel: TPanel;
  addrlbl: TLabel;
  valuelbl: TLabel;
  leftLayout: TLayout;
  rightLayout: TLayout;
begin
  with frmHome do
  begin
        switchTab(PageControl, HistoryDetails);
if TfmxObject(Sender).TagObject=nil then exit;

    th := THistoryHolder(TfmxObject(Sender).TagObject).history;
     HistoryTransactionValue.Text := BigIntegertoFloatStr(th.CountValues,
      CurrentCryptoCurrency.decimals);
    if th.confirmation > 0 then
      historyTransactionConfirmation.Text := IntToStr(th.confirmation) +
        ' Confirmation(s)'
    else
      historyTransactionConfirmation.Text := 'Unconfirmed';

    HistoryTransactionDate.Text := FormatDateTime('dd mmm yyyy hh:mm',
      UnixToDateTime(strToIntdef(th.Data, 0)));
    HistoryTransactionID.Text := cutEveryNChar(4, th.TransactionID);
    if th.typ = 'IN' then
      HistoryTransactionSendReceive.Text := 'Receive'
    else if th.typ = 'OUT' then
      HistoryTransactionSendReceive.Text := 'Send'
    else
    begin
      showmessage('History Transaction type error');
      exit();
    end;
    i := 0;
    while i <= HistoryTransactionVertScrollBox.Content.ChildrenCount - 1 do
    begin
      fmxObject := HistoryTransactionVertScrollBox.Content.Children[i];

      if LeftStr(fmxObject.name, length('HistoryValueAddressPanel_')) = 'HistoryValueAddressPanel_'
      then
      begin
        fmxObject.DisposeOf;
        i := 0;
      end;
      inc(i);

    end;
    for i := 0 to length(th.values) - 1 do
    begin
      Panel := TPanel.Create(HistoryTransactionVertScrollBox);
      Panel.Align := TAlignLayout.Top;
      Panel.Height := 36;
      Panel.Visible := true;
      Panel.Tag := i;
      Panel.TagString := th.addresses[i];
      Panel.name := 'HistoryValueAddressPanel_' + IntToStr(i);
      Panel.Parent := HistoryTransactionVertScrollBox;
      Panel.Position.Y := 1000 + Panel.Height * i;
      Panel.OnGesture := CopyToClipboard;
      Panel.Touch.GestureManager := GestureManager1;
      Panel.Touch.InteractiveGestures := [TInteractiveGesture.DoubleTap,
        TInteractiveGesture.LongTap];

      leftLayout := TLayout.Create(Panel);
      leftLayout.Visible := true;
      leftLayout.Align := TAlignLayout.Left;
      leftLayout.Width := 10;
      leftLayout.Parent := Panel;

      rightLayout := TLayout.Create(Panel);
      rightLayout.Visible := true;
      rightLayout.Align := TAlignLayout.Right;
      rightLayout.Width := 10;
      rightLayout.Parent := Panel;

      valuelbl := TLabel.Create(Panel);
      valuelbl.Align := TAlignLayout.Top;
      valuelbl.Visible := true;
      valuelbl.Parent := Panel;
      valuelbl.Position.Y:=26;
      valuelbl.Text := BigIntegertoFloatStr(th.values[i],
        CurrentCryptoCurrency.decimals);
      valuelbl.TextSettings.HorzAlign := TTextAlign.Trailing;

      addrlbl := TLabel.Create(Panel);
      addrlbl.Align := TAlignLayout.Top;
      addrlbl.Visible := true;
      addrlbl.Parent := Panel;
      addrlbl.Text := th.addresses[i];
      addrlbl.TextSettings.HorzAlign := TTextAlign.Leading;

    end;


  end;
end;

procedure walletHide(Sender: TObject);
var
  Panel: TPanel;
  fmxObj: TfmxObject;
  wdArray: TCryptoCurrencyArray;
  i: Integer;
begin
  if Sender is TButton then
  begin

    Panel := TPanel(TfmxObject(Sender).Parent);

    if (Panel.TagObject is TWalletInfo) and
      (TWalletInfo(Panel.TagObject).coin <> 4) then
    begin

      wdArray := CurrentAccount.getWalletWithX(TWalletInfo(Panel.TagObject).X,
        TWalletInfo(Panel.TagObject).coin);

      for i := 0 to length(wdArray) - 1 do
      begin
        wdArray[i].deleted := true;
      end;

    end
    else
    begin
      CryptoCurrency(Panel.TagObject).deleted := true;
    end;

    Panel.DisposeOf;
  end;

end;

procedure importCheck;
var
  comkey: AnsiString;
  notkey: AnsiString;
  WData: AnsiString;
  ts: TStringList;
  wd: TwalletInfo;
  request: AnsiString;
begin
 with frmHome do begin
  try
    if isHex(WIFEdit.Text) then
    begin
      if (length(WIFEdit.Text) <> 64) then
      begin
        popupWindow.Create('Key too short');
        exit;
      end;

      if HexPrivKeyCompressedRadioButton.IsChecked then
      begin
        LoadingKeyDataAniIndicator.Enabled := false;
        LoadingKeyDataAniIndicator.Visible := false;
      end
      else if HexPrivKeyNotCompressedRadioButton.IsChecked then
      begin
        LoadingKeyDataAniIndicator.Enabled := false;
        LoadingKeyDataAniIndicator.Visible := false;
      end
      else
      begin

        if Layout31.Visible = true then
        begin
          popupWindow.Create
            ('You must check whether your hey is compressed or not');
          exit;
        end;
        LoadingKeyDataAniIndicator.Enabled := true;
        LoadingKeyDataAniIndicator.Visible := true;
        if newcoinID <> 4 then
        begin

          comkey := secp256k1_get_public(WIFEdit.Text, false);
          notkey := secp256k1_get_public(WIFEdit.Text, true);
          wd := TwalletInfo.Create(newcoinID, -1, -1,
            Bitcoin_PublicAddrToWallet(comkey, AvailableCoin[newcoinID].p2pk),
            'Imported');
          wd.pub := comkey;
          request := HODLER_URL + 'getSegwitBalance.php?coin=' + AvailableCoin
            [wd.coin].name + '&' + segwitParameters(wd);
          WData := getDataOverHTTP(request);
          ts := TStringList.Create();
          ts.Text := WData;
          if strToFloatDef(ts[0], 0) + strToFloatDef(ts[1], 0) = 0 then
          begin
            WData := getDataOverHTTP(HODLER_URL + 'getSegwitHistory.php?coin=' +
              AvailableCoin[wd.coin].name + '&' + segwitParameters(wd));
            if length(WData) > 10 then
            begin

              Tthread.Synchronize(nil,
                procedure
                begin
                  HexPrivKeyCompressedRadioButton.IsChecked := true;
                  ts.free;
                  ts := nil;
                  wd.free;
                  wd := nil;
                  exit;
                end);

            end;
          end
          else
          begin
            Tthread.Synchronize(nil,
              procedure
              begin
                HexPrivKeyCompressedRadioButton.IsChecked := true;
                ts.free;
                ts := nil;
                wd.free;
                wd := nil;
                exit;
              end);
          end;
          if ts <> nil then
            ts.free;
          if wd <> nil then
            wd.free;

          wd := TwalletInfo.Create(newcoinID, -1, -1,
            Bitcoin_PublicAddrToWallet(notkey,
            AvailableCoin[newcoinID].p2pk), '');
          wd.pub := comkey;

          WData := getDataOverHTTP(HODLER_URL + 'getBalance.php?coin=' +
            AvailableCoin[wd.coin].name + '&address=' + wd.addr);
          ts := TStringList.Create();
          ts.Text := WData;

          if strToFloatDef(ts[0], 0) + strToFloatDef(ts[1], 0) = 0 then
          begin
            Data := getDataOverHTTP(HODLER_URL + 'getHistory.php?coin=' +
              AvailableCoin[wd.coin].name + '&address=' + wd.addr);
            if length(WData) > 10 then
            begin
              Tthread.Synchronize(nil,
                procedure
                begin
                  HexPrivKeyNotCompressedRadioButton.IsChecked := true;
                  ts.free;
                  ts := nil;
                  wd.free;
                  wd := nil;
                  exit; // +
                end);
            end;
          end
          else
          begin
            Tthread.Synchronize(nil,
              procedure
              begin
                HexPrivKeyNotCompressedRadioButton.IsChecked := true;
                ts.free;
                ts := nil;
                wd.free;
                wd := nil;
                exit;
              end);
          end;
          if ts <> nil then
            ts.free;
          if wd <> nil then
            wd.free;

          Tthread.Synchronize(nil,
            procedure
            begin
              LoadingKeyDataAniIndicator.Enabled := false;
              LoadingKeyDataAniIndicator.Visible := false;
              Layout31.Visible := true;
            end);

          exit;
        end;
        // Parsing for ETH
        if newcoinID = 4 then
        begin

          comkey := secp256k1_get_public(WIFEdit.Text, true);

          wd := TwalletInfo.Create(newcoinID, -1, -1,
            Ethereum_PublicAddrToWallet(comkey), 'Imported');
          wd.pub := comkey;

          Tthread.Synchronize(nil,
            procedure
            begin
              LoadingKeyDataAniIndicator.Enabled := false;
              LoadingKeyDataAniIndicator.Visible := false;
              Layout31.Visible := true;
              HexPrivKeyNotCompressedRadioButton.IsChecked := true;
            end);

          wd.free;

          exit;

        end;

      end
    end

  except
    on E: Exception do
    begin
      popupWindow.Create('Private key is not valid');
      exit;
    end;
  end;
  btnDecryptSeed.OnClick := ImportPrivateKey;
  decryptSeedBackTabItem := PageControl.ActiveTab;
  PageControl.ActiveTab := descryptSeed;
  btnDSBack.OnClick := backBtnDecryptSeed;
end;
end;

end.