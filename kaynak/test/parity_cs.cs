// mcs -langversion:5 ../win/Engine.cs parity_cs.cs -out:parity_cs.exe ; mono parity_cs.exe <tohum> <genislik> <tick>
// parity_js.js ile birebir ayni senaryo (ayni tiklamalar, ayni ekran degisimi).
using System;
using System.IO;
using System.Text;
using TaskbarKedileri;

static class ParityCs
{
    static int Main(string[] args)
    {
        double seed = double.Parse(args[0]);
        int W = int.Parse(args[1]), N = int.Parse(args[2]);
        Engine e = new Engine(W, seed);
        StringBuilder o = new StringBuilder();
        o.Append(e.Digest()).Append('\n');
        string[] names = { "tarcin", "maya", "zilli" };
        for (int t = 0; t < N; t++)
        {
            int m = t % 300;
            if (m == 150 || m == 158 || m == 166 || m == 230) o.Append("poke ").Append(e.Poke("dogis")).Append('\n');
            if (t % 977 == 0) o.Append("poke ").Append(e.Poke(names[t % 3])).Append('\n');
            if (t == (N >> 1)) e.SetScreen(W - 333);
            e.Step();
            o.Append(e.Digest()).Append('\n');
        }
        Console.Out.Write(o.ToString());
        return 0;
    }
}
