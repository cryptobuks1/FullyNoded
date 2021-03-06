//
//  CreateMultisigViewController.swift
//  FullyNoded
//
//  Created by Peter on 8/29/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import UIKit

class CreateMultisigViewController: UIViewController, UITextViewDelegate, UITextFieldDelegate {
    
    var spinner = ConnectingView()
    var cointType = "0"
    var blockheight = 0
    var m = Int()
    var n = Int()
    var keysString = ""
    var isDone = Bool()
    var ccXfp = ""
    var ccXpub = ""
    
    @IBOutlet weak var closeOutlet: UIButton!
    @IBOutlet weak var derivationField: UITextField!
    @IBOutlet weak var fingerprintField: UITextField!
    @IBOutlet weak var wordsTextView: UITextView!
    @IBOutlet weak var xpubField: UITextField!
    @IBOutlet weak var textView: UITextView!

    override func viewDidLoad() {
        super.viewDidLoad()
        textView.clipsToBounds = true
        textView.layer.cornerRadius = 8
        textView.layer.borderColor = UIColor.lightGray.cgColor
        textView.layer.borderWidth = 0.5
        wordsTextView.clipsToBounds = true
        wordsTextView.layer.cornerRadius = 5
        wordsTextView.layer.borderColor = UIColor.darkGray.cgColor
        wordsTextView.layer.borderWidth = 0.5
        wordsTextView.delegate = self
        xpubField.delegate = self
        spinner.addConnectingView(vc: self, description: "fetching chain type...")
        if ccXpub != "" && ccXfp != "" {
            closeOutlet.alpha = 1
            textView.text += ccXfp + ":" + ccXpub + "\n\n"
            showAlert(vc: self, title: "Coldcard xpub added ✅", message: "You can add more xpubs or tap the refresh button to get Fully Noded to create them for you. The seed words are *never* saved, make sure you write them down, they will be gone forever!")
        } else {
            closeOutlet.alpha = 0
        }
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.dismissKeyboard (_:)))
        tapGesture.numberOfTapsRequired = 1
        self.view.addGestureRecognizer(tapGesture)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        getChain()
    }
    
    @objc func dismissKeyboard(_ sender: UITapGestureRecognizer) {
        fingerprintField.resignFirstResponder()
        textView.resignFirstResponder()
        wordsTextView.resignFirstResponder()
        xpubField.resignFirstResponder()
        derivationField.resignFirstResponder()
    }
    
    @IBAction func closeAction(_ sender: Any) {
        DispatchQueue.main.async { [weak self] in
            self?.dismiss(animated: true, completion: nil)
        }
    }
    
    
    @IBAction func refreshButton(_ sender: Any) {
        addSigner()
    }
    
    @IBAction func deleteButton(_ sender: Any) {
        wordsTextView.text = ""
        fingerprintField.text = ""
        xpubField.text = ""
        textView.text = ""
    }
    
    @IBAction func addButton(_ sender: Any) {
        let xpub = xpubField.text ?? ""
        let fingerprint = fingerprintField.text ?? ""
        
        if fingerprint != "" && xpub != "" {
            textView.text += fingerprint + ":" + xpub + "\n\n"
            wordsTextView.text = ""
            fingerprintField.text = ""
            xpubField.text = ""
            derivationField.isUserInteractionEnabled = false
            
        } else if fingerprint == "" && xpub != "" {
            if let fp = Keys.fingerprint(masterKey: xpub) {
                textView.text += fp + ":" + xpub + "\n\n"
                wordsTextView.text = ""
                fingerprintField.text = ""
                xpubField.text = ""
            }
            derivationField.isUserInteractionEnabled = false
        } else {
            showAlert(vc: self, title: "Error", message: "You must add a valid extended public key")
        }
    }
    
    @IBAction func createButton(_ sender: Any) {
        promptToCreate()
    }
    
    private func getChain() {
        Reducer.makeCommand(command: .getblockchaininfo, param: "") { [unowned vc = self] (response, errorMessage) in
            if let dict = response as? NSDictionary {
                if let blocks = dict["blocks"] as? Int {
                    vc.blockheight = blocks
                }
                if let chain = dict["chain"] as? String {
                    DispatchQueue.main.async { [weak self] in
                        if chain != "main" {
                            self?.cointType = "1"
                        }
                        if self != nil {
                            self?.derivationField.text = "m/48'/\(self!.cointType)'/0'/2'"
                        }
                    }
                    vc.spinner.removeConnectingView()
                    showAlert(vc: vc, title: "Multisig Creator", message: "You can create/recover multisig wallets with this tool, all that is required are xpubs.\n\nThis tool is for users who have an understanding of multisig and how it works, the derivation default's to m/48'/0'/0'/2', you may set a custom derivation, your xpub's must be derived from this path!\n\nIf you want Fully Noded to create the xpub's for you you may tap the refresh button.\n\nAlternatively supply your own xpub/Zpub/tpub/Vpub or bip39 words.\n\nThis wallet will strictly be created as watch-only, any seed words generated or added will *NOT* be remembered and are *ONLY* used to derive xpub's, you may add the signers at anytime to Fully Noded seperately from this process via the signer view if you would like the app to sign your transactions.")
                } else {
                    vc.spinner.removeConnectingView()
                    showAlert(vc: vc, title: "Error", message: "error fetching chain type: \(errorMessage ?? "")")
                }
            } else {
                vc.spinner.removeConnectingView()
                showAlert(vc: vc, title: "Error", message: "error fetching chain type: \(errorMessage ?? "")")
            }
        }
    }
    
    private func promptToCreate() {
        if textView.text != "" {
            let process = (textView.text!).replacingOccurrences(of: "\n\n", with: " ")
            let arr = process.split(separator: " ")
            var array = [[String:String]]()
            for part in arr {
                let xfpAndKey = part.split(separator: ":")
                let dict = ["fingerprint":"\(xfpAndKey[0])","xpub":"\(xfpAndKey[1])"]
                array.append(dict)
            }
            if arr.count > 0 {
                DispatchQueue.main.async { [unowned vc = self] in
                    var alertStyle = UIAlertController.Style.actionSheet
                    if (UIDevice.current.userInterfaceIdiom == .pad) {
                      alertStyle = UIAlertController.Style.alert
                    }
                    let alert = UIAlertController(title: "How many signers are required to spend funds?", message: "", preferredStyle: alertStyle)
                    for (i, _) in arr.enumerated() {
                        alert.addAction(UIAlertAction(title: "\(i + 1)", style: .default, handler: { action in
                            vc.create(m: i + 1, parts: array)
                        }))
                    }
                    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
                    alert.popoverPresentationController?.sourceView = vc.view
                    vc.present(alert, animated: true, completion: nil)
                }
            }
        }
    }
    
    private func create(m: Int, parts: [[String:String]]) {
        spinner.addConnectingView(vc: self, description: "creating multisig wallet...")
        var keys = ""
        for (i, signer) in parts.enumerated() {
            let fingerprint = signer["fingerprint"]
            var xpub = signer["xpub"]
            if !xpub!.hasPrefix("xpub") && !xpub!.hasPrefix("tpub") {
                xpub = XpubConverter.convert(extendedKey: xpub!)
            }
            if fingerprint != "" {
                if xpub != "" {
                    guard let derivationPathProcessed = derivationProcessed()?.replacingOccurrences(of: "m/", with: "") else {
                        return
                    }
                    
                    keys += "[\(fingerprint!)/\(derivationPathProcessed)]\(xpub!)/0/*"
                    keysString += "\(fingerprint!):\(xpub!)\n"
                    if i < parts.count - 1 {
                        keys += ","
                    }
                    if i + 1 == parts.count {
                        let rawPrimDesc = "wsh(sortedmulti(\(m),\(keys)))"
                        let accountMap = ["descriptor":rawPrimDesc,"label":"\(m) of \(parts.count)", "blockheight": blockheight] as [String:Any]
                        ImportWallet.accountMap(accountMap) { [unowned vc = self] (success, errorDescription) in
                            if success {
                                vc.walletSuccessfullyCreated(mofn: "\(m) of \(parts.count)")
                            } else {
                                vc.spinner.removeConnectingView()
                                showAlert(vc: vc, title: "There was an error!", message: "Something went wrong during the wallet creation process: \(errorDescription ?? "unknown error")")
                            }
                        }
                    }
                } else {
                    self.spinner.removeConnectingView()
                    showAlert(vc: self, title: "xpub missing!", message: "We can not create a multisig wallet wiouth a set of bip39 words and xpub, we need one or the other.")
                }
            } else {
                self.spinner.removeConnectingView()
                showAlert(vc: self, title: "Fingerprint missing!", message: "Please add the correct fingerprint for the master key so offline signers will be able to sign.")
            }
        }
    }
    
    private func walletSuccessfullyCreated(mofn: String) {
        isDone = true
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.spinner.removeConnectingView()
            
            NotificationCenter.default.post(name: .refreshWallet, object: nil, userInfo: nil)
            
            var alertStyle = UIAlertController.Style.actionSheet
            
            if (UIDevice.current.userInterfaceIdiom == .pad) {
              alertStyle = UIAlertController.Style.alert
            }
            
            let alert = UIAlertController(title: "\(mofn) successfully created ✓", message: "The wallet has been activated and the wallet view is refreshing, tap done to go back", preferredStyle: alertStyle)
            
            if self.derivationField.text == "m/48'/1'/0'/2'" || self.derivationField.text == "m/48'/0'/0'/2'" {
                alert.addAction(UIAlertAction(title: "Export", style: .default, handler: { action in
                    self.export(mofn: mofn)
                }))
            }
            
            alert.addAction(UIAlertAction(title: "Done", style: .default, handler: { action in
                DispatchQueue.main.async {
                    if self.navigationController != nil {
                        self.navigationController?.popToRootViewController(animated: true)
                    } else {
                        self.dismiss(animated: true, completion: nil)
                    }
                }
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { _ in }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    private func addSigner() {
        if let words = Keys.seed() {
            convertWords(words: words)
        }
    }
    
    private func derivationProcessed() -> String? {
        guard let text = derivationField.text?.replacingOccurrences(of: "’", with: "'"),
            Keys.vaildPath(text.replacingOccurrences(of: "’", with: "'")) else {
            return nil
        }
        
        return text
    }
    
    private func clear() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.wordsTextView.text = ""
            self.fingerprintField.text = ""
            self.xpubField.text = ""
        }
    }
    
    private func convertWords(words: String) {
        guard let mk = Keys.masterKey(words: words, coinType: cointType, passphrase: ""),
            let fingerprint = Keys.fingerprint(masterKey: mk) else {
                clear()
                showAlert(vc: self, title: "Invalid words", message: "The words need to conform with BIP39")
                return
        }
        
        guard let derivationPath = derivationProcessed() else {
            clear()
            showAlert(vc: self, title: "Invalid derivation", message: "You must input a valid bip32 derivation path, when in doubt stick with the default")
            return
        }
        
        guard let xpub = Keys.xpub(path: derivationPath, masterKey: mk),
            let _ = XpubConverter.zpub(xpub: xpub) else {
                clear()
                showAlert(vc: self, title: "Unable to derive xpub", message: "Looks like you added an invalid extended key")
                return
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.xpubField.text = xpub
            self.fingerprintField.text = fingerprint
            self.wordsTextView.text = words
        }
    }
    
    private func export(mofn: String) {
        if derivationField.text == "m/48'/1'/0'/2'" || derivationField.text == "m/48'/0'/0'/2'" {
            let text = """
            Name: Fully Noded
            Policy: \(mofn)
            Derivation: \(derivationField.text ?? "error getting the derivation path, you should report this issue")
            Format: P2WSH
            
            \(keysString)
            """
            if let url = exportMultisigWalletToURL(data: text.dataUsingUTF8StringEncoding) {
                DispatchQueue.main.async { [unowned vc = self] in
                    vc.textView.text = text
                    let activityViewController = UIActivityViewController(activityItems: ["Multisig Export", url], applicationActivities: nil)
                    if UIDevice.current.userInterfaceIdiom == .pad {
                        activityViewController.popoverPresentationController?.sourceView = self.view
                        activityViewController.popoverPresentationController?.sourceRect = CGRect(x: 0, y: 0, width: 100, height: 100)
                    }
                    vc.present(activityViewController, animated: true) {}
                }
            }
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.endEditing(true)
        return true
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        if textView == wordsTextView && wordsTextView.text != "" {
            convertWords(words: textView.text)
        }
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        if textField == xpubField {
            let extendedKey = xpubField.text ?? ""
            if extendedKey != "" {
                if extendedKey.hasPrefix("xpub") || extendedKey.hasPrefix("tpub") {
                    if let _ = XpubConverter.zpub(xpub: extendedKey) {
                        
                    } else {
                        updateXpubField("")
                        showAlert(vc: self, title: "Error", message: "Invalid xpub")
                    }
                } else if extendedKey.hasPrefix("Zpub") || extendedKey.hasPrefix("Vpub") {
                    if let xpub = XpubConverter.convert(extendedKey: extendedKey) {
                        updateXpubField(xpub)
                        showAlert(vc: self, title: "Valid xpub ✅", message: "You added a Zpub or Vpub, which is fine but your node only understands xpubs, so we did you a favor and converted it for you.")
                    } else {
                        updateXpubField("")
                        showAlert(vc: self, title: "Error", message: "Invalid extended key. It must be either an xpub, tpub, Zpub or Vpub")
                    }
                }
            }
        }
    }
    
    func textViewDidChange(_ textView: UITextView) {
        if textView == wordsTextView {
            if let _ = Keys.masterKey(words: textView.text, coinType: cointType, passphrase: "") {
                convertWords(words: wordsTextView.text ?? "")
            }
        }
    }
    
    private func updateXpubField(_ xpub: String) {
        DispatchQueue.main.async { [weak self] in
            self?.xpubField.text = xpub
        }
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
