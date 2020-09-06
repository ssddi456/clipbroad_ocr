#!powershell
#requires -version 2.0
 
[CmdletBinding()]
param
(
)
 
$script:ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
function PSScriptRoot { $MyInvocation.ScriptName | Split-Path }
Trap { throw $_ }
 
function Register-ClipboardWatcher
{
    if (-not (Test-Path Variable:Global:ClipboardWatcher))
    {
        Register-ClipboardWatcherType
        $Global:ClipboardWatcher = New-Object ClipboardWatcher
 
        Register-EngineEvent -SourceIdentifier PowerShell.Exiting -SupportEvent -Action `
        {
            Unregister-ClipboardWatcher
        }
    }
 
    return $Global:ClipboardWatcher
}
 
function Unregister-ClipboardWatcher
{
    if (Test-Path Variable:Global:ClipboardWatcher)
    {
        $Global:ClipboardWatcher.Dispose();
        Remove-Variable ClipboardWatcher -Scope Global
        Unregister-Event -SourceIdentifier ClipboardWatcher
    }
}
 
function Register-ClipboardWatcherType
{
    Add-Type -ReferencedAssemblies System.Windows.Forms, System.Drawing -Language CSharpVersion3 -TypeDefinition `
@"
using System;
using System.Drawing;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows.Forms;
 
public class ClipboardWatcher : IDisposable
{
    readonly Thread _formThread;
    bool _disposed;
 
    public ClipboardWatcher()
    {
        _formThread = new Thread(() => { new ClipboardWatcherForm(this); })
                      {
                          IsBackground = true
                      };
 
        _formThread.SetApartmentState(ApartmentState.STA);
        _formThread.Start();
    }
 
    public void Dispose()
    {
        if (_disposed)
            return;
        Disposed();
        if (_formThread != null && _formThread.IsAlive)
            _formThread.Abort();
        _disposed = true;
        GC.SuppressFinalize(this);
    }
 
    ~ClipboardWatcher()
    {
        Dispose();
    }
 
    public event Action<string> ClipboardTextChanged = delegate { };
    public event Action ClipboardImageChanged = delegate { };
    public event Action Disposed = delegate { };
 
    public void OnClipboardTextChanged(string text)
    {
        ClipboardTextChanged(text);
    }
    public void OnClipboardImageChanged()
    {
        ClipboardImageChanged();
    }
}
 
public class ClipboardWatcherForm : Form
{
    public ClipboardWatcherForm(ClipboardWatcher clipboardWatcher)
    {
        HideForm();
        RegisterWin32();
        ClipboardTextChanged += clipboardWatcher.OnClipboardTextChanged;
        ClipboardImageChanged += clipboardWatcher.OnClipboardImageChanged;
        clipboardWatcher.Disposed += () => InvokeIfRequired(Dispose);
        Disposed += (sender, args) => UnregisterWin32();
        Application.Run(this);
    }
 
    void InvokeIfRequired(Action action)
    {
        if (InvokeRequired)
            Invoke(action);
        else
            action();
    }
 
    public event Action<string> ClipboardTextChanged = delegate { };
    public event Action ClipboardImageChanged = delegate { };
 
    void HideForm()
    {
        FormBorderStyle = FormBorderStyle.None;
        ShowInTaskbar = false;
        Load += (sender, args) => { Size = new Size(0, 0); };
    }
 
    void RegisterWin32()
    {
        User32.AddClipboardFormatListener(Handle);
    }
 
    void UnregisterWin32()
    {
        if (IsHandleCreated)
            User32.RemoveClipboardFormatListener(Handle);
    }
 
    protected override void WndProc(ref Message m)
    {
        switch ((WM) m.Msg)
        {
            case WM.WM_CLIPBOARDUPDATE:
                ClipboardChanged();
                break;
 
            default:
                base.WndProc(ref m);
                break;
        }
    }
 
    void ClipboardChanged()
    {
        if (Clipboard.ContainsText())
            ClipboardTextChanged(Clipboard.GetText());
        else if (Clipboard.ContainsImage())
            ClipboardImageChanged();
    }
}
 
public enum WM
{
    WM_CLIPBOARDUPDATE = 0x031D
}
 
public class User32
{
    const string User32Dll = "User32.dll";
 
    [DllImport(User32Dll, CharSet = CharSet.Auto)]
    public static extern bool AddClipboardFormatListener(IntPtr hWndObserver);
 
    [DllImport(User32Dll, CharSet = CharSet.Auto)]
    public static extern bool RemoveClipboardFormatListener(IntPtr hWndObserver);
}
"@
 
}
 
function Register-ClipboardTextChangedEvent
{
    param
    (
        [ScriptBlock] $Action
    )
 
    $watcher = Register-ClipboardWatcher
    Register-ObjectEvent $watcher -EventName ClipboardTextChanged -Action $Action -SourceIdentifier ClipboardTextWatcher
}

 
function Register-ClipboardImageChangedEvent
{
    param
    (
        [ScriptBlock] $Action
    )
 
    $watcher = Register-ClipboardWatcher
    Register-ObjectEvent $watcher -EventName ClipboardImageChanged -Action $Action -SourceIdentifier ClipboardImageWatcher
}
 
Register-ClipboardTextChangedEvent -Action `
    {
        param
        (
            [string] $text
        )
 
        Write-Host "Text arrived @ clipboard: $text"
    }

Register-ClipboardImageChangedEvent -Action `
    {
        param
        (
        )

        $img = get-clipboard -format image
        $filepath = $PSScriptRoot + '\temp\test' + ([Math]::Round((Get-Date).ToFileTime() / 10000 - 11644473600000)) + '.png'
        $img.save( $filepath )
        # get imaga base64 here
        # curl post to ocr
        #  /rest/2.0/ocr/v1/general_basic

        python ocr.py $filepath
    }

$continue = $true
while($continue)
{
    if ([console]::KeyAvailable)
    {
        echo "Exit with `"q`"";
        $x = [System.Console]::ReadKey() 

        switch ( $x.key)
        {
            q { $continue = $false }
        }
    } 
    else
    {
        # Your while loop commands go  here......
        Start-Sleep -Milliseconds 500
    }    
} 