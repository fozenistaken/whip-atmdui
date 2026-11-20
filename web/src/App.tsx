import { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { CheckCircle2, CreditCard, Hourglass, Lock, Landmark, ShieldCheck, Receipt, Banknote } from 'lucide-react';
import { clsx, type ClassValue } from 'clsx';
import { twMerge } from 'tailwind-merge';

function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

type ScreenType =
  | 'none' | 'welcome' | 'card_insert' | 'pin_entry' | 'main_menu'
  | 'withdraw' | 'withdraw_amount' | 'deposit' | 'transfer_account'
  | 'transfer_amount' | 'balance' | 'success' | 'receipt_prompt' | 'card_eject' | 'receipt_view' | 'no_card';

interface SessionData {
  playerName: string;
  bankBalance: number;
  quickAmounts: number[];
  pinTitle?: string;
}

type Locale = Record<string, string>;

const resourceName = () => (window as any).GetParentResourceName ? (window as any).GetParentResourceName() : 'atmdui';

export default function App() {
  const isNative = typeof (window as any).GetParentResourceName !== 'undefined' || typeof (window as any).invokeNative !== 'undefined';
  const isDui = window.location.href.includes('dui=true') || !isNative;
  const [screen, setScreen] = useState<ScreenType>(isDui ? 'welcome' : 'none');
  const [session, setSession] = useState<SessionData>({ playerName: '', bankBalance: 0, quickAmounts: [20, 50, 100, 200, 500] });
  const [highlighted, setHighlighted] = useState<string>('');
  const [pinDots, setPinDots] = useState<number>(0);
  const [inputValue, setInputValue] = useState<string>('0');
  const [processing, setProcessing] = useState<{ active: boolean, duration?: number, progress?: number }>({ active: false });
  const [toast, setToast] = useState<{ msg: string, type: 'error' | 'success' | 'info' } | null>(null);
  const [successData, setSuccessData] = useState<{ msg: string, amt: number, bal: number }>({ msg: '', amt: 0, bal: 0 });
  const [receiptData, setReceiptData] = useState<any>(null);
  const [currentModel, setCurrentModel] = useState<string>('');
  const [locale, setLocale] = useState<Locale>({});
  const [bankName, setBankName] = useState<string>('FLEECA');
  const [cardCost, setCardCost] = useState<number | null>(null);
  const [transferTo, setTransferTo] = useState<string>('');
  const [rows, setRows] = useState<{ left: number[], right: number[] }>({ left: [14.75, 38.25, 61.75, 85.25], right: [14.75, 38.25, 61.75, 85.25] });
  const [calibrate, setCalibrate] = useState<boolean>(false);
  const [now, setNow] = useState<Date>(new Date());

  const t = (key: string, fallback: string) => locale[key] || fallback;

  useEffect(() => {
    const handleMessage = (event: MessageEvent) => {
      const { action, data } = event.data || {};
      if (!action) return;

      switch (action) {
        case 'SET_MODEL':
          setCurrentModel(data.model || '');
          if (data.rows?.left?.length === 4 && data.rows?.right?.length === 4) setRows(data.rows);
          break;
        case 'SET_ROWS':
          if (data.rows?.left?.length === 4 && data.rows?.right?.length === 4) setRows(data.rows);
          break;
        case 'CALIBRATE':
          setCalibrate(!!data.on);
          break;
        case 'SET_SCREEN':
          setScreen(data.screen);
          setHighlighted('');
          if (data.screen === 'pin_entry') {
            setPinDots(0);
            setSession(s => ({ ...s, pinTitle: data.data?.title || '' }));
          } else if (data.screen === 'welcome') {
            setPinDots(0);
            setInputValue('0');
          }
          if (data.data?.balance !== undefined) setSession(s => ({ ...s, bankBalance: data.data.balance }));
          if (data.data?.name) setSession(s => ({ ...s, playerName: data.data.name }));
          if (data.data?.quickAmounts) setSession(s => ({ ...s, quickAmounts: data.data.quickAmounts }));
          if (data.data?.cost !== undefined) setCardCost(data.data.cost);
          if (data.data?.account !== undefined) setTransferTo(String(data.data.account));
          if (data.data?.message) setSuccessData({
            msg: data.data.message, amt: data.data.amount || 0, bal: data.data.newBalance || 0
          });
          if (data.screen === 'receipt_view' && data.data) {
            setReceiptData(data.data);
          }
          break;
        case 'HIGHLIGHT_BUTTON':
          setHighlighted(data.buttonId || '');
          break;
        case 'PIN_UPDATE':
          setPinDots(data.length || 0);
          break;
        case 'AMOUNT_UPDATE':
          setInputValue(data.value || '0');
          break;
        case 'playSound':
          if (data.sound === 'dispenser') {
            const audio = new Audio('dispenser.ogg');
            audio.volume = 0.5;
            audio.play().catch(e => console.error('Audio block:', e));
          }
          break;
        case 'SET_PROCESSING':
          setProcessing({ active: !!data.processing, duration: data.duration, progress: 0 });
          break;
        case 'UPDATE_PROGRESS':
          setProcessing(p => ({ ...p, progress: data.progress }));
          break;
        case 'NOTIFICATION':
          setToast({ msg: data.message, type: data.type || 'error' });
          setTimeout(() => setToast(null), 3000);
          break;
        case 'INIT_SESSION': {
          const d = data?.data ?? data ?? {};
          setSession({
            playerName: d.playerName || '',
            bankBalance: d.bankBalance || 0,
            quickAmounts: d.quickAmounts || [20, 50, 100, 200, 500]
          });
          if (d.locale) setLocale(d.locale);
          document.documentElement.lang = d.language || 'en';
          if (d.bankName) setBankName(String(d.bankName));
          break;
        }
      }
    };

    const handleKeydown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        fetch(`https://${resourceName()}/closeReceipt`, { method: 'POST' }).then(() => {
          setScreen('welcome');
        }).catch(() => {});
      }
    };

    window.addEventListener('message', handleMessage);
    window.addEventListener('keydown', handleKeydown);
    return () => {
      window.removeEventListener('message', handleMessage);
      window.removeEventListener('keydown', handleKeydown);
    };
  }, []);

  useEffect(() => {
    if (!isDui) return;
    const id = setInterval(() => setNow(new Date()), 1000);
    return () => clearInterval(id);
  }, [isDui]);

  useEffect(() => {
    if (!isNative) {
      setTimeout(() => {
        window.postMessage({ action: 'INIT_SESSION', data: { playerName: 'Michael De Santa', bankBalance: 1211650, quickAmounts: [20, 50, 100, 200, 500] } }, '*');
      }, 100);
    }
  }, [isNative]);

  const pageVariants = {
    initial: { opacity: 0, y: 12 },
    animate: { opacity: 1, y: 0, transition: { duration: 0.25, ease: 'easeOut' } },
    exit: { opacity: 0, y: -8, transition: { duration: 0.15, ease: 'easeIn' } }
  };

  const formatMoney = (val: number) => Number(val || 0).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
  const showMoney = (v: any) => typeof v === 'number' ? `$${v.toLocaleString('en-US')}` : String(v ?? '');
  const isHL = (id: string) => highlighted === id;
  const pad2 = (n: number) => String(n).padStart(2, '0');
  const timeText = `${pad2(now.getHours())}:${pad2(now.getMinutes())}`;
  const dateText = `${pad2(now.getDate())}.${pad2(now.getMonth() + 1)}.${now.getFullYear()}`;

  const SideBtn = ({ id, label, right, accent, position }: { id: string, label: string, right?: boolean, accent?: boolean, position: number }) => {
    const hl = isHL(id);
    const top = (right ? rows.right : rows.left)[position - 1] ?? 50;
    return (
      <div className={cn(
        'absolute flex items-center w-[95%] h-[8.5vh] -translate-y-1/2',
        right ? 'right-0 justify-end' : 'left-0 justify-start',
      )} style={{ top: `${top}%` }}>
        <div className={cn(
          'relative flex items-center h-full w-full gap-[1vw] px-[1.2vw] border-[3px] transition-colors duration-150',
          right ? 'flex-row-reverse rounded-l-[1.2vh]' : 'flex-row rounded-r-[1.2vh]',
          right ? 'border-r-0' : 'border-l-0',
          hl
            ? (accent ? 'bg-[#fde2e2] border-[#fde2e2] text-[#8f1d1d]' : 'bg-[#f2f7f4] border-[#f2f7f4] text-[#05432d]')
            : (accent ? 'bg-[#5b1414]/90 border-[#a83232] text-[#fde2e2]' : 'bg-[#0b4a33]/90 border-[#2a8a60] text-white')
        )}>
          <span className={cn('text-[3.4vh] leading-none', hl ? '' : (accent ? 'text-[#f87171]' : 'text-[#7ee2b0]'))}>
            {right ? '▶' : '◀'}
          </span>
          <span className={cn(
            'flex-1 min-w-0 font-sans font-extrabold uppercase tracking-wide leading-[1.05] break-words line-clamp-2',
            right ? 'text-right' : 'text-left',
            label.length <= 8 ? 'text-[2.9vh]' : label.length <= 12 ? 'text-[2.4vh]' : label.length <= 16 ? 'text-[2.1vh]' : 'text-[1.8vh]',
          )}>{label}</span>
        </div>
      </div>
    );
  };

  const TopBar = ({ title }: { title?: string }) => (
    <div className="absolute top-0 left-0 right-0 h-[9%] z-20 flex items-center justify-between px-[2.5vw] bg-gradient-to-b from-[#0d8a4e] to-[#09703f] border-b-[0.5vh] border-[#59d394] shadow-[0_0.6vh_1.2vh_rgba(0,0,0,0.45)]">
      <div className="flex items-baseline gap-[0.8vw]">
        <span className="font-sans font-black italic text-[4.6vh] tracking-tight text-white leading-none">{bankName}</span>
        <span className="font-sans font-bold text-[2vh] tracking-[0.35em] text-[#c9f2dc]">BANK</span>
      </div>
      {title && <span className="font-sans font-bold text-[2.6vh] uppercase tracking-[0.12em] text-white/95">{title}</span>}
      <div className="flex items-center gap-[1.2vw] text-[#dff7ea]">
        <Lock size={22} strokeWidth={2.5} />
        <span className="font-sans font-semibold text-[2.2vh] tabular-nums">{dateText}</span>
        <span className="font-sans font-extrabold text-[2.8vh] tabular-nums">{timeText}</span>
      </div>
    </div>
  );

  const BottomBar = ({ text }: { text: string }) => (
    <div className="absolute bottom-0 left-0 right-0 h-[7%] z-20 flex items-center justify-center bg-[#041d15]/95 border-t-[0.4vh] border-[#1d6b4b]">
      <span className="font-sans font-bold text-[2.4vh] tracking-[0.08em] text-[#fde047] uppercase text-center">{text}</span>
    </div>
  );

  const Center = ({ children }: { children: any }) => (
    <div className="absolute top-[11%] bottom-[9%] left-[26%] right-[26%] flex flex-col justify-center items-center z-20 text-center">
      {children}
    </div>
  );

  const fitSize = (s: string) => s.length <= 7 ? 9 : s.length <= 9 ? 7.6 : s.length <= 11 ? 6.4 : s.length <= 13 ? 5.4 : 4.6;
  const BigNumber = ({ value, prefix }: { value: string, prefix?: string }) => {
    const vh = fitSize(value);
    return (
      <div className="font-sans font-black text-white leading-none tabular-nums tracking-tight whitespace-nowrap" style={{ fontSize: `${vh}vh` }}>
        {prefix && <span className="text-[#7ee2b0] align-top mr-[0.4vw]" style={{ fontSize: `${Math.max(3, vh * 0.6)}vh` }}>{prefix}</span>}
        {value}
      </div>
    );
  };

  const isFleeca = currentModel === 'prop_fleeca_atm';

  if (!isDui) {
    const kind = receiptData?.type;
    const kindText = ({ withdraw: t('withdraw', 'Withdrawal'), deposit: t('deposit', 'Deposit'), transfer: t('transfer', 'Transfer') } as Record<string, string>)[kind] || kind;
    return (
      <div className="w-full h-full relative overflow-hidden bg-transparent">
        {screen === 'receipt_view' && receiptData && (
          <div className="absolute inset-0 z-[200] flex items-center justify-center bg-black/60 pointer-events-auto">
            <motion.div initial={{ y: 400, opacity: 0 }} animate={{ y: 0, opacity: 1 }} exit={{ y: 400, opacity: 0 }} transition={{ type: 'spring', damping: 22, stiffness: 120 }}
              className="relative w-[360px] text-[#1f2933] font-mono shadow-2xl"
              style={{ background: 'linear-gradient(to bottom, #fbfaf6, #f3efe4)' }}>
              <div className="h-3 w-full" style={{ background: 'radial-gradient(circle at 6px -2px, transparent 6px, #fbfaf6 6.5px) 0 0 / 12px 12px repeat-x' }} />
              <div className="px-7 pt-3 pb-8">
                <div className="text-center border-b-2 border-dashed border-[#9aa5b1] pb-4 mb-4">
                  <p className="font-sans font-black italic text-3xl tracking-tight text-[#0b6b3a]">{bankName}</p>
                  <p className="text-[11px] tracking-[0.3em] mt-1">ATM RECEIPT</p>
                </div>
                <div className="space-y-2 text-[13px]">
                  <div className="flex justify-between"><span>DATE</span><span className="font-bold">{receiptData.date}</span></div>
                  <div className="flex justify-between"><span>TRANSACTION</span><span className="font-bold uppercase">{kindText}</span></div>
                  {kind === 'transfer' && <div className="flex justify-between"><span>TO ACCOUNT</span><span className="font-bold">{receiptData.account}</span></div>}
                  <div className="flex justify-between"><span>TERMINAL</span><span className="font-bold">SA-{(receiptData.date || '').replace(/\D/g, '').slice(-4) || '0001'}</span></div>
                </div>
                <div className="border-y-2 border-[#1f2933] my-5 py-3 flex justify-between items-center text-xl font-black">
                  <span>AMOUNT</span><span>{showMoney(receiptData.amount)}</span>
                </div>
                <div className="text-center text-[13px]">
                  <p className="tracking-widest">{t('available_balance', 'AVAILABLE BALANCE').toUpperCase()}</p>
                  <p className="text-lg font-bold mt-1">{showMoney(receiptData.balance)}</p>
                </div>
                <div className="mt-6 text-center text-[11px] leading-relaxed text-[#52606d]">
                  <p>THANK YOU FOR BANKING WITH {bankName}</p>
                  <p>KEEP THIS RECEIPT FOR YOUR RECORDS</p>
                </div>
              </div>
              <button onClick={() => { fetch(`https://${resourceName()}/closeReceipt`, { method: 'POST' }).then(() => setScreen('none')).catch(() => {}) }}
                className="absolute -top-12 right-0 bg-white/10 hover:bg-white/20 text-white border border-white/30 px-4 py-2 rounded shadow-lg transition-colors font-sans">
                {t('back', 'Close')} [ESC]
              </button>
            </motion.div>
          </div>
        )}
      </div>
    );
  }

  const withSides = screen !== 'welcome' && screen !== 'card_insert' && screen !== 'card_eject' && screen !== 'success';
  const titles: Partial<Record<ScreenType, string>> = {
    pin_entry: t('enter_pin', 'Enter PIN'),
    main_menu: t('main_menu', 'Select transaction'),
    withdraw: t('quick_cash', 'Quick cash'),
    withdraw_amount: t('withdraw', 'Withdraw'),
    deposit: t('deposit', 'Deposit'),
    transfer_account: t('transfer', 'Transfer'),
    transfer_amount: t('transfer', 'Transfer'),
    balance: t('balance', 'Balance'),
    receipt_prompt: t('transaction_complete', 'Transaction complete'),
    no_card: t('insert_card', 'Insert card'),
  };
  const hints: Partial<Record<ScreenType, string>> = {
    welcome: t('insert_card', 'Please insert your card'),
    card_insert: t('reading_card', 'Reading your card, please wait'),
    card_eject: t('take_card', 'Please take your card'),
    pin_entry: t('press_enter', 'Press ENTER to confirm · CANCEL to clear'),
    main_menu: t('main_menu', 'Select a transaction'),
    withdraw: t('quick_cash', 'Select an amount'),
    withdraw_amount: t('press_enter', 'Press ENTER to confirm · CANCEL to clear'),
    deposit: t('press_enter', 'Press ENTER to confirm · CANCEL to clear'),
    transfer_account: t('press_enter', 'Press ENTER to confirm · CANCEL to clear'),
    transfer_amount: t('press_enter', 'Press ENTER to confirm · CANCEL to clear'),
    balance: t('back', 'Back'),
    success: successData.msg,
    receipt_prompt: t('receipt_question', 'Would you like a receipt?'),
    no_card: t('new_card', 'Issue a new card?'),
  };

  return (
    <div className="w-full h-full relative overflow-hidden bg-transparent">
      <div
        className="w-full h-full relative overflow-hidden text-white select-none font-sans flex items-center justify-center bg-[#04241a]"
        style={isFleeca ? {
          transformOrigin: 'top left',
          transform: 'translate(0.39vw, 50.78vh) scale(0.4921, 0.4648)'
        } : undefined}
      >

        <div className="absolute inset-0 z-0 bg-[radial-gradient(ellipse_at_50%_45%,#0d4a35_0%,#06301f_55%,#031a12_100%)]" />
        <div className="absolute inset-0 z-0 pointer-events-none opacity-[0.18] bg-[linear-gradient(rgba(255,255,255,0.07)_1px,transparent_1px)] bg-[size:100%_3px]" />
        <div className="absolute inset-0 z-[60] pointer-events-none shadow-[inset_0_0_8vh_rgba(0,0,0,0.75)]" />
        <div className="absolute inset-0 z-[61] pointer-events-none bg-[linear-gradient(115deg,rgba(255,255,255,0.06)_0%,rgba(255,255,255,0)_35%)]" />

        {withSides && <TopBar title={titles[screen]} />}
        {withSides && <BottomBar text={hints[screen] || ''} />}

        {withSides && (
          <>
            <div className="absolute top-0 bottom-0 left-2 w-[25%] z-30">
              {screen === 'main_menu' && (
                <>
                  <SideBtn id="side_l1" position={1} label={t('withdraw', 'Withdraw')} />
                  <SideBtn id="side_l2" position={2} label={t('deposit', 'Deposit')} />
                  <SideBtn id="side_l3" position={3} label={t('transfer', 'Transfer')} />
                  <SideBtn id="side_l4" position={4} label={t('balance', 'Balance')} />
                </>
              )}
              {screen === 'withdraw' && session.quickAmounts.slice(0, 4).map((amt, i) => (
                <SideBtn key={i} id={`side_l${i + 1}`} position={i + 1} label={`$${amt}`} />
              ))}
              {screen === 'receipt_prompt' && (
                <SideBtn id="side_l1" position={1} label={t('yes', 'Yes')} />
              )}
              {screen === 'no_card' && (
                <SideBtn id="side_l4" position={4} label={t('cancel', 'Cancel')} accent />
              )}
            </div>
            <div className="absolute top-0 bottom-0 right-0 w-[25%] z-30">
              {screen === 'main_menu' && (
                <SideBtn id="side_r4" position={4} label={t('exit', 'Exit')} right accent />
              )}
              {screen === 'withdraw' && (
                <>
                  <SideBtn id="side_r1" position={1} label={`$${session.quickAmounts[4]}`} right />
                  <SideBtn id="side_r2" position={2} label={t('other_amount', 'Other amount')} right />
                  <SideBtn id="side_r4" position={4} label={t('back', 'Back')} right accent />
                </>
              )}
              {(screen === 'withdraw_amount' || screen === 'deposit' || screen === 'transfer_amount' || screen === 'transfer_account' || screen === 'pin_entry') && (
                <>
                  <SideBtn id="side_r3" position={3} label={t('confirm', 'Confirm')} right />
                  {screen !== 'pin_entry' && <SideBtn id="side_r4" position={4} label={t('cancel', 'Cancel')} right accent />}
                </>
              )}
              {screen === 'balance' && (
                <SideBtn id="side_r4" position={4} label={t('back', 'Back')} right accent />
              )}
              {screen === 'receipt_prompt' && (
                <SideBtn id="side_r4" position={4} label={t('no', 'No')} right accent />
              )}
              {screen === 'no_card' && (
                <SideBtn id="side_r4" position={4} label={t('new_card', 'New card')} right />
              )}
            </div>
          </>
        )}

        <AnimatePresence mode="wait">

          {(screen === 'welcome' || screen === 'card_insert' || screen === 'card_eject') && (
            <motion.div key={screen} variants={pageVariants} initial="initial" animate="animate" exit="exit" className="absolute inset-0 z-20 flex flex-col items-center justify-center">
              <div className="absolute top-0 left-0 right-0 h-[16%] flex items-center justify-center bg-gradient-to-b from-[#0d8a4e] to-[#09703f] border-b-[0.6vh] border-[#59d394]">
                <span className="font-sans font-black italic text-[8vh] tracking-tight text-white leading-none">{bankName}</span>
                <span className="ml-[1vw] font-sans font-bold text-[3vh] tracking-[0.4em] text-[#c9f2dc] self-end mb-[3.2vh]">BANK</span>
              </div>

              <p className="font-sans font-extrabold text-[5.2vh] text-white tracking-wide mt-[6vh]">
                {screen === 'welcome' ? t('welcome', 'Welcome') : screen === 'card_insert' ? t('processing', 'Processing...') : t('take_card', 'Please take your card')}
              </p>

              <div className="relative mt-[5vh] w-[34vh] h-[24vh]">
                <motion.div
                  className="absolute left-1/2 top-0 w-[22vh] h-[14vh] -ml-[11vh] rounded-[1.4vh] bg-gradient-to-br from-[#e8f3ee] to-[#9fc9b4] border-[0.4vh] border-white/70 shadow-[0_1vh_2vh_rgba(0,0,0,0.5)] overflow-hidden"
                  animate={screen === 'card_eject' ? { y: [90, 0], opacity: [0, 1] } : { y: [0, 90], opacity: [1, 0] }}
                  transition={{ duration: screen === 'card_insert' ? 0.9 : 1.8, repeat: Infinity, repeatDelay: 0.6, ease: 'easeInOut' }}
                >
                  <div className="absolute top-[2.4vh] left-[2vh] w-[4vh] h-[3vh] rounded-[0.5vh] bg-gradient-to-br from-[#f6d77a] to-[#c9a227]" />
                  <div className="absolute bottom-[2vh] left-[2vh] right-[2vh] h-[1.2vh] rounded bg-[#4b6b5d]/40" />
                  <span className="absolute top-[2vh] right-[2vh] font-sans font-black italic text-[2.6vh] text-[#0b6b3a]">{bankName}</span>
                </motion.div>
                <div className="absolute left-1/2 top-[15vh] w-[28vh] h-[2.4vh] -ml-[14vh] rounded-full bg-[#010806] border-[0.4vh] border-[#2a8a60] shadow-[0_0_2vh_rgba(89,211,148,0.45)]" />
              </div>

              <div className="absolute bottom-[8%] flex items-center gap-[1.2vw] bg-[#041d15]/90 border-[0.4vh] border-[#1d6b4b] px-[3vw] py-[2vh] rounded-[1.4vh]">
                <CreditCard size={44} className="text-[#fde047]" />
                <p className="font-sans font-extrabold text-[3vh] tracking-[0.12em] text-[#fde047] uppercase">{hints[screen]}</p>
              </div>
            </motion.div>
          )}

          {screen === 'pin_entry' && (
            <motion.div key="pin_entry" variants={pageVariants} initial="initial" animate="animate" exit="exit" className="absolute inset-0 z-20">
              <Center>
                <ShieldCheck size={64} className="text-[#7ee2b0] mb-[2.5vh]" strokeWidth={1.8} />
                <h2 className="font-sans font-extrabold text-[4.2vh] text-white tracking-wide mb-[4vh] uppercase">{session.pinTitle || t('enter_pin', 'Enter your PIN')}</h2>
                <div className="flex gap-[1.4vw]">
                  {[0, 1, 2, 3].map(i => (
                    <div key={i} className={cn(
                      'w-[9vh] h-[11vh] rounded-[1vh] border-[0.5vh] flex items-center justify-center transition-colors duration-150',
                      i < pinDots ? 'bg-[#f2f7f4] border-white' : 'bg-[#021610] border-[#2a8a60]',
                      i === pinDots && 'border-[#fde047]'
                    )}>
                      {i < pinDots && <span className="text-[#05432d] font-black text-[6vh] leading-none">*</span>}
                    </div>
                  ))}
                </div>
                <p className="mt-[4vh] text-[2.2vh] text-[#9cc9b5] tracking-wide">{t('pin_hint', 'Shield the keypad while you type your PIN')}</p>
              </Center>
            </motion.div>
          )}

          {screen === 'main_menu' && (
            <motion.div key="main_menu" variants={pageVariants} initial="initial" animate="animate" exit="exit" className="absolute inset-0 z-20">
              <Center>
                <p className="font-sans font-semibold text-[2.6vh] text-[#9cc9b5] uppercase tracking-[0.2em]">{t('welcome', 'Welcome')}</p>
                <h1 className="font-sans font-black text-[5vh] text-white tracking-wide capitalize mt-[0.8vh] mb-[5vh] max-w-full truncate">{session.playerName}</h1>
                <div className="w-full border-[0.4vh] border-[#2a8a60] bg-[#021610]/80 rounded-[1.4vh] py-[3.5vh] px-[2vw]">
                  <p className="font-sans font-bold text-[2vh] tracking-[0.3em] text-[#9cc9b5] mb-[1.2vh] uppercase">{t('available_balance', 'Available balance')}</p>
                  <BigNumber prefix="$" value={formatMoney(session.bankBalance)} />
                </div>
              </Center>
            </motion.div>
          )}

          {screen === 'withdraw' && (
            <motion.div key="withdraw" variants={pageVariants} initial="initial" animate="animate" exit="exit" className="absolute inset-0 z-20">
              <Center>
                <Banknote size={110} strokeWidth={1.2} className="text-[#7ee2b0] mb-[3vh]" />
                <p className="font-sans font-extrabold text-[4.2vh] text-white uppercase tracking-wide">{t('quick_cash', 'Quick cash')}</p>
                <p className="mt-[1.5vh] text-[2.4vh] text-[#9cc9b5]">{t('other_amount', 'Other amount')}: ▶</p>
                <div className="mt-[4vh] max-w-full flex flex-col items-center bg-[#021610]/80 border-[0.3vh] border-[#2a8a60] px-[2vw] py-[1.4vh] rounded-[1vh] tabular-nums">
                  <span className="text-[#9cc9b5] text-[2vh] uppercase tracking-[0.15em]">{t('available_balance', 'Available balance')}</span>
                  <span className="font-bold text-[3vh] whitespace-nowrap">${formatMoney(session.bankBalance)}</span>
                </div>
              </Center>
            </motion.div>
          )}

          {(screen === 'withdraw_amount' || screen === 'deposit' || screen === 'transfer_amount' || screen === 'transfer_account') && (
            <motion.div key="amount_entry" variants={pageVariants} initial="initial" animate="animate" exit="exit" className="absolute inset-0 z-20">
              <Center>
                <p className="font-sans font-extrabold text-[3.6vh] uppercase text-white tracking-wide mb-[3.5vh]">
                  {screen === 'transfer_account' ? t('enter_account', 'Enter account number') : t('enter_amount', 'Enter amount')}
                </p>
                <div className="w-full bg-[#f2f7f4] rounded-[1.2vh] border-[0.6vh] border-[#59d394] py-[3vh] px-[2vw] flex justify-end items-center shadow-[inset_0_0.6vh_1.2vh_rgba(0,0,0,0.25)]">
                  <span className="font-sans font-black text-[#05301f] leading-none tabular-nums tracking-tight flex items-center whitespace-nowrap"
                    style={{ fontSize: `${fitSize((screen === 'transfer_account' ? 'WB-' : '$') + inputValue)}vh` }}>
                    {screen === 'transfer_account'
                      ? <span className="text-[4.5vh] text-[#2a6b50] mr-[0.6vw]">WB-</span>
                      : <span className="text-[5.5vh] text-[#2a6b50] mr-[0.4vw]">$</span>}
                    {inputValue}
                    <motion.span className="inline-block w-[0.5vh] h-[7vh] bg-[#05301f] ml-[0.6vw]" animate={{ opacity: [1, 0, 1] }} transition={{ duration: 1, repeat: Infinity }} />
                  </span>
                </div>
                {screen === 'transfer_amount' && (
                  <p className="mt-[3vh] text-[2.4vh] text-[#9cc9b5]">{t('transfer_to', 'To')}: <span className="text-white font-bold tabular-nums">WB-{transferTo.padStart(6, '0')}</span></p>
                )}
                {screen !== 'transfer_account' && (
                  <p className="mt-[3vh] text-[2.3vh] text-[#9cc9b5] tabular-nums">
                    {t('available_balance', 'Available balance')}: <span className="text-white font-bold">${formatMoney(session.bankBalance)}</span>
                  </p>
                )}
              </Center>
            </motion.div>
          )}

          {screen === 'success' && (
            <motion.div key="success" variants={pageVariants} initial="initial" animate="animate" exit="exit" className="absolute inset-0 z-20 flex flex-col items-center justify-center">
              <TopBar />
              <div className="flex flex-col items-center w-[52%] mt-[4vh]">
                <div className="w-[13vh] h-[13vh] rounded-full flex items-center justify-center bg-[#0d8a4e] border-[0.6vh] border-[#59d394] mb-[3.5vh]">
                  <CheckCircle2 size={72} className="text-white" strokeWidth={2.2} />
                </div>
                <h2 className="font-sans font-black text-[4.6vh] text-white uppercase tracking-wide text-center mb-[4.5vh]">{successData.msg}</h2>
                <div className="w-full bg-[#021610]/85 border-[0.4vh] border-[#2a8a60] rounded-[1.4vh] px-[2.5vw] py-[3vh] space-y-[2.2vh]">
                  <div className="flex justify-between items-baseline">
                    <span className="text-[2.3vh] text-[#9cc9b5] uppercase tracking-[0.2em]">{t('amount', 'Amount')}</span>
                    <span className="font-black text-[4.4vh] tabular-nums">${formatMoney(successData.amt)}</span>
                  </div>
                  <div className="h-[0.3vh] bg-[#1d6b4b]" />
                  <div className="flex justify-between items-baseline">
                    <span className="text-[2.3vh] text-[#7ee2b0] uppercase tracking-[0.2em]">{t('current_balance', 'Current balance')}</span>
                    <span className="font-black text-[4.4vh] text-[#7ee2b0] tabular-nums">${formatMoney(successData.bal)}</span>
                  </div>
                </div>
              </div>
              <BottomBar text={successData.msg} />
            </motion.div>
          )}

          {screen === 'balance' && (
            <motion.div key="balance" variants={pageVariants} initial="initial" animate="animate" exit="exit" className="absolute inset-0 z-20">
              <Center>
                <Landmark size={84} strokeWidth={1.4} className="text-[#7ee2b0] mb-[3vh]" />
                <div className="w-full border-[0.4vh] border-[#2a8a60] bg-[#021610]/80 rounded-[1.4vh] py-[4vh] px-[2vw]">
                  <p className="font-sans font-bold text-[2.2vh] tracking-[0.3em] text-[#9cc9b5] mb-[1.4vh] uppercase">{t('current_balance', 'Current balance')}</p>
                  <BigNumber prefix="$" value={formatMoney(session.bankBalance)} />
                </div>
                <p className="mt-[3vh] text-[2.2vh] text-[#9cc9b5]">{dateText} {timeText}</p>
              </Center>
            </motion.div>
          )}

          {screen === 'receipt_prompt' && (
            <motion.div key="receipt" variants={pageVariants} initial="initial" animate="animate" exit="exit" className="absolute inset-0 z-20">
              <Center>
                <Receipt size={96} className="text-[#7ee2b0] mb-[3.5vh]" strokeWidth={1.4} />
                <h2 className="font-sans font-black text-[4.6vh] text-white uppercase tracking-wide">{t('receipt_question', 'Would you like a receipt?')}</h2>
              </Center>
            </motion.div>
          )}

          {screen === 'no_card' && (
            <motion.div key="no_card" variants={pageVariants} initial="initial" animate="animate" exit="exit" className="absolute inset-0 z-20">
              <Center>
                <CreditCard size={96} className="text-[#fca5a5] mb-[3vh]" strokeWidth={1.4} />
                <h2 className="font-sans font-black text-[4.2vh] text-white uppercase tracking-wide mb-[2.5vh]">{t('no_card_title', 'No card found')}</h2>
                <p className="text-[#c7e3d5] text-[2.4vh] leading-relaxed max-w-[92%]">
                  {t('no_card_text', 'You need a bank card to use this ATM. A new card is linked to your main account.')}
                </p>
                {cardCost !== null && (
                  <div className="mt-[3.5vh] bg-[#021610]/80 border-[0.3vh] border-[#2a8a60] px-[2vw] py-[1.4vh] rounded-[1vh] text-[2.6vh]">
                    <span className="text-[#9cc9b5] mr-[0.6vw]">{t('card_fee', 'Card fee')}:</span>
                    <span className="font-bold tabular-nums">${formatMoney(cardCost)}</span>
                  </div>
                )}
              </Center>
            </motion.div>
          )}

        </AnimatePresence>

        {calibrate && (
          <div className="absolute inset-0 z-[150] pointer-events-none">
            {(['left', 'right'] as const).map(side => rows[side].map((top, i) => (
              <div key={side + i} className={cn('absolute flex items-center gap-[0.6vw] -translate-y-1/2', side === 'left' ? 'left-0' : 'right-0 flex-row-reverse')}
                style={{ top: `${top}%` }}>
                <div className="w-[3vw] h-[0.6vh] bg-[#fde047]" />
                <span className="font-black text-[2.6vh] text-[#fde047] bg-black/70 px-[0.6vw] rounded">
                  {side === 'left' ? 'L' : 'R'}{i + 1} {top}%
                </span>
              </div>
            )))}
          </div>
        )}

        <AnimatePresence>
          {processing.active && (
            <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} className="absolute inset-0 z-[100] bg-[#031a12]/90 flex flex-col items-center justify-center">
              <motion.div animate={{ rotate: [0, 180, 180, 360] }} transition={{ duration: 2.4, repeat: Infinity, times: [0, 0.4, 0.5, 0.9], ease: 'easeInOut' }}>
                <Hourglass size={96} className="text-[#fde047]" strokeWidth={1.6} />
              </motion.div>
              <h2 className="font-sans font-black text-[4.4vh] text-white uppercase tracking-[0.12em] mt-[4vh]">{t('please_wait', 'Please wait')}</h2>
              <p className="text-[2.4vh] text-[#9cc9b5] mt-[1.2vh] tracking-wide">{t('processing', 'Your transaction is being processed')}</p>

              {processing.duration && (
                <div className="w-[56vh] h-[3vh] mt-[5vh] bg-[#021610] border-[0.3vh] border-[#2a8a60] rounded-full overflow-hidden relative">
                  <motion.div
                    className="absolute inset-0 bg-[#59d394] origin-left"
                    initial={{ scaleX: 0 }}
                    animate={{ scaleX: Math.min(1, (processing.progress || 0) / 100) }}
                    transition={{ ease: 'linear', duration: 0.1 }}
                  />
                  <div className="absolute inset-0 flex items-center justify-center text-[1.8vh] font-bold text-white mix-blend-difference tabular-nums">
                    {Math.round(processing.progress || 0)}%
                  </div>
                </div>
              )}
            </motion.div>
          )}

          {toast && (
            <motion.div initial={{ y: -40, opacity: 0 }} animate={{ y: 0, opacity: 1 }} exit={{ y: -40, opacity: 0 }} className="absolute top-[11%] left-0 right-0 z-[200] flex justify-center">
              <div className={cn(
                'max-w-[70%] px-[2.5vw] py-[1.8vh] flex items-center gap-[1vw] border-[0.4vh] rounded-[1.2vh] shadow-2xl text-center',
                toast.type === 'error' ? 'bg-[#5b1414] border-[#f87171] text-white' : 'bg-[#0b4a33] border-[#59d394] text-white'
              )}>
                <span className={cn('w-[2vh] h-[2vh] rounded-full', toast.type === 'error' ? 'bg-[#f87171]' : 'bg-[#59d394]')} />
                <span className="font-sans text-[2.6vh] font-extrabold tracking-[0.06em] uppercase">{toast.msg}</span>
              </div>
            </motion.div>
          )}
        </AnimatePresence>

        {!isNative && (
          <div className="absolute bottom-[8%] left-[1%] z-[999] bg-[#021610]/95 border-2 border-[#2a8a60] p-2 rounded-xl w-[24%] opacity-80 hover:opacity-100">
            <div className="text-[#7ee2b0] font-bold text-sm uppercase tracking-wider mb-2">Preview</div>
            <div className="flex flex-wrap gap-1">
              {(['welcome', 'card_insert', 'pin_entry', 'main_menu', 'withdraw', 'withdraw_amount', 'deposit', 'transfer_account', 'transfer_amount', 'balance', 'success', 'receipt_prompt', 'no_card', 'card_eject'] as ScreenType[]).map(s => (
                <button key={s} onClick={() => setScreen(s)} className={cn('text-xs px-2 py-1 rounded border', s === screen ? 'bg-[#59d394] text-[#05301f] border-[#59d394]' : 'bg-[#0b4a33] text-white border-[#2a8a60]')}>{s}</button>
              ))}
              <button onClick={() => setProcessing(p => ({ active: !p.active, duration: 8000, progress: 40 }))} className="text-xs px-2 py-1 rounded border bg-[#0b4a33] text-white border-[#2a8a60]">processing</button>
              <button onClick={() => { setToast({ msg: 'Insufficient funds', type: 'error' }); setTimeout(() => setToast(null), 2000) }} className="text-xs px-2 py-1 rounded border bg-[#5b1414] text-white border-[#a83232]">error</button>
              <button onClick={() => setHighlighted(h => h === 'side_l1' ? 'side_r4' : 'side_l1')} className="text-xs px-2 py-1 rounded border bg-[#0b4a33] text-white border-[#2a8a60]">highlight</button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
