// Render Markdown from the audit ledger with StringTemplate 4.
//
//   java -cp tools/st4/lib/ST4-4.3.4.jar:tools/st4/lib/antlr-runtime-3.5.3.jar \
//        tools/st4/Render.java audit/ledger.tsv GROUP.stg OUT.md [GROUP.stg OUT.md ...]
//
// audit/ledger.tsv is the single source of truth.  This program only
// groups its rows into lists; it computes no numbers.  Every count in the
// output is `length(...)` of one of those lists, evaluated by the template.
// Each group file must define main(m).  Any template error fails the run.

import java.io.IOException;
import java.io.StringWriter;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Map;
import java.util.TreeMap;
import java.util.function.Predicate;

import org.stringtemplate.v4.AutoIndentWriter;
import org.stringtemplate.v4.ST;
import org.stringtemplate.v4.STErrorListener;
import org.stringtemplate.v4.STGroupFile;
import org.stringtemplate.v4.misc.STMessage;

public class Render {

  static final List<String> LEVELS = List.of("Micro", "Meso", "Macro");
  static final List<String> TIER_LABELS = List.of(
      "closed under the global context",
      "Reals construction axioms only (allowlist)",
      "allowlist plus a registered exception");

  /** One ledger row. */
  public static final class Entry {
    public final String name, module, ident, level, kind;
    public final int tier;
    public final List<String> assumptions, repairs;
    public final boolean qed, qex, open, closed;

    Entry(String[] c) {
      name = c[0];
      int dot = name.lastIndexOf('.');
      module = name.substring(0, dot);
      ident = name.substring(dot + 1);
      level = c[1];
      kind = c[2];
      tier = Integer.parseInt(c[3]);
      assumptions = c[4].equals("-") ? List.of() : Arrays.asList(c[4].split(","));
      open = c[5].equals("open");
      repairs = (c[5].equals("-") || open) ? List.of() : Arrays.asList(c[5].split(","));
      qed = kind.equals("QED");
      qex = kind.equals("QEX");
      closed = assumptions.isEmpty();
    }
  }

  public static final class Level {
    public final String name;
    public final List<Entry> entries, qed, qex, open;

    Level(String name, List<Entry> all) {
      this.name = name;
      entries = filter(all, e -> e.level.equals(name));
      qed = filter(entries, e -> e.qed);
      qex = filter(entries, e -> e.qex);
      open = filter(entries, e -> e.open);
    }
  }

  public static final class Tier {
    public final int tier;
    public final String label;
    public final List<Entry> entries, qed, qex;

    Tier(int tier, List<Entry> all) {
      this.tier = tier;
      label = TIER_LABELS.get(tier);
      entries = filter(all, e -> e.tier == tier);
      qed = filter(entries, e -> e.qed);
      qex = filter(entries, e -> e.qex);
    }
  }

  public static final class Axiom {
    public final String name;
    public final List<Entry> users;

    Axiom(String name, List<Entry> users) {
      this.name = name;
      this.users = users;
    }
  }

  public static final class Model {
    public final String source;
    public final List<Entry> entries, qed, qex, open, repaired;
    public final List<Level> levels = new ArrayList<>();
    public final List<Tier> tiers = new ArrayList<>();
    public final List<Axiom> axioms = new ArrayList<>();

    Model(String source, List<Entry> all) {
      this.source = source;
      entries = all;
      qed = filter(all, e -> e.qed);
      qex = filter(all, e -> e.qex);
      open = filter(all, e -> e.open);
      repaired = filter(qex, e -> !e.open);
      for (String l : LEVELS) levels.add(new Level(l, all));
      for (int t = 0; t < TIER_LABELS.size(); t++) tiers.add(new Tier(t, all));
      Map<String, List<Entry>> byAxiom = new TreeMap<>();
      for (Entry e : all)
        for (String a : e.assumptions)
          byAxiom.computeIfAbsent(a, k -> new ArrayList<>()).add(e);
      byAxiom.forEach((a, users) -> axioms.add(new Axiom(a, users)));
    }
  }

  static List<Entry> filter(List<Entry> xs, Predicate<Entry> p) {
    List<Entry> out = new ArrayList<>();
    for (Entry e : xs) if (p.test(e)) out.add(e);
    return out;
  }

  static List<Entry> readLedger(Path path) throws IOException {
    List<Entry> rows = new ArrayList<>();
    boolean header = true;
    for (String line : Files.readAllLines(path, StandardCharsets.UTF_8)) {
      if (line.isBlank() || line.startsWith("#")) continue;
      String[] c = line.split("\t", -1);
      if (c.length != 6) throw new IOException(path + ": expected 6 columns: " + line);
      if (header) { header = false; continue; }
      if (!LEVELS.contains(c[1])) throw new IOException(path + ": bad level: " + line);
      rows.add(new Entry(c));
    }
    return rows;
  }

  public static void main(String[] args) throws IOException {
    if (args.length < 3 || args.length % 2 == 0) {
      System.err.println("usage: Render LEDGER.tsv GROUP.stg OUT.md [GROUP.stg OUT.md ...]");
      System.exit(2);
    }
    Model m = new Model(args[0], readLedger(Path.of(args[0])));
    List<String> errors = new ArrayList<>();
    STErrorListener listener = new STErrorListener() {
      public void compileTimeError(STMessage msg) { errors.add(msg.toString()); }
      public void runTimeError(STMessage msg) { errors.add(msg.toString()); }
      public void IOError(STMessage msg) { errors.add(msg.toString()); }
      public void internalError(STMessage msg) { errors.add(msg.toString()); }
    };
    for (int i = 1; i < args.length; i += 2) {
      STGroupFile group = new STGroupFile(args[i], '$', '$');
      group.setListener(listener);
      ST st = group.getInstanceOf("main");
      if (st == null) {
        errors.add(args[i] + ": no template main(m)");
        continue;
      }
      st.add("m", m);
      StringWriter out = new StringWriter();
      st.write(new AutoIndentWriter(out, "\n"), listener);
      if (errors.isEmpty()) {
        String text = out.toString();
        if (!text.endsWith("\n")) text += "\n";
        Files.writeString(Path.of(args[i + 1]), text, StandardCharsets.UTF_8);
      }
    }
    if (!errors.isEmpty()) {
      errors.forEach(e -> System.err.println("render: error: " + e));
      System.exit(1);
    }
  }
}
