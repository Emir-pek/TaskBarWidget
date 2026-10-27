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
using System;
using System.Collections.Generic;
using System.Globalization;
using System.Text;

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
