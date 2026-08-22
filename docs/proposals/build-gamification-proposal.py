from reportlab.lib.pagesizes import A4
from reportlab.lib.units import mm
from reportlab.lib import colors
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.enums import TA_LEFT
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle,
    HRFlowable, KeepTogether, ListFlowable, ListItem,
)

D = "/usr/share/fonts/truetype/dejavu/"
pdfmetrics.registerFont(TTFont("Sans", D + "DejaVuSans.ttf"))
pdfmetrics.registerFont(TTFont("Sans-B", D + "DejaVuSans-Bold.ttf"))
pdfmetrics.registerFont(TTFont("Sans-I", D + "DejaVuSerif.ttf"))  # no oblique shipped; serif stands in for emphasis
pdfmetrics.registerFont(TTFont("Serif-B", D + "DejaVuSerif-Bold.ttf"))

SAGE = colors.HexColor("#3F5C4A")
SAGE_L = colors.HexColor("#7D9C88")
INK = colors.HexColor("#1F2320")
MUTED = colors.HexColor("#5C635E")
RULE = colors.HexColor("#D8DDD9")
BAND = colors.HexColor("#EFF3EF")
WARN = colors.HexColor("#8A5A1E")
WARN_BG = colors.HexColor("#FBF3E6")

def S(name, **kw):
    base = dict(name=name, fontName="Sans", fontSize=9.5, leading=14.5,
                textColor=INK, alignment=TA_LEFT)
    base.update(kw)
    return ParagraphStyle(**base)

st = {
    "title":   S("title", fontName="Serif-B", fontSize=23, leading=27, textColor=SAGE),
    "sub":     S("sub", fontSize=11, leading=16, textColor=MUTED),
    "h1":      S("h1", fontName="Serif-B", fontSize=13.5, leading=17,
                 textColor=SAGE, spaceBefore=16, spaceAfter=7),
    "h2":      S("h2", fontName="Sans-B", fontSize=10, leading=14,
                 textColor=INK, spaceBefore=9, spaceAfter=4),
    "body":    S("body", spaceAfter=6),
    "small":   S("small", fontSize=8.5, leading=12.5, textColor=MUTED),
    "cell":    S("cell", fontSize=8.8, leading=12.6),
    "cellb":   S("cellb", fontName="Sans-B", fontSize=8.8, leading=12.6),
    "cellh":   S("cellh", fontName="Sans-B", fontSize=8.6, leading=12,
                 textColor=colors.white),
    "warn":    S("warn", fontSize=9.3, leading=14, textColor=colors.HexColor("#5A3E10")),
    "quote":   S("quote", fontName="Sans-I", fontSize=9.3, leading=14, textColor=MUTED),
}

def bullets(items, style="body"):
    return ListFlowable(
        [ListItem(Paragraph(t, st[style]), leftIndent=12) for t in items],
        bulletType="bullet", bulletFontName="Sans", bulletFontSize=9,
        bulletColor=SAGE_L, leftIndent=14, bulletOffsetY=-1, spaceAfter=4,
    )

def table(rows, widths, header=True, zebra=True):
    data = []
    for r_i, row in enumerate(rows):
        style = "cellh" if (header and r_i == 0) else "cell"
        data.append([Paragraph(c, st[style]) if isinstance(c, str) else c for c in row])
    t = Table(data, colWidths=widths, repeatRows=1 if header else 0)
    cmds = [
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("TOPPADDING", (0, 0), (-1, -1), 6),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 6),
        ("LEFTPADDING", (0, 0), (-1, -1), 8),
        ("RIGHTPADDING", (0, 0), (-1, -1), 8),
        ("LINEBELOW", (0, 0), (-1, -2), 0.4, RULE),
    ]
    if header:
        cmds += [("BACKGROUND", (0, 0), (-1, 0), SAGE),
                 ("LINEBELOW", (0, 0), (-1, 0), 0, colors.white)]
    if zebra:
        start = 1 if header else 0
        for i in range(start, len(rows)):
            if (i - start) % 2 == 1:
                cmds.append(("BACKGROUND", (0, i), (-1, i), colors.HexColor("#F7F9F7")))
    t.setStyle(TableStyle(cmds))
    return t

def callout(title, body_paras, bg=WARN_BG, fg=WARN):
    inner = [Paragraph(title, ParagraphStyle("ct", fontName="Sans-B", fontSize=9.5,
                                             leading=13, textColor=fg, spaceAfter=5))]
    for p in body_paras:
        inner.append(Paragraph(p, st["warn"]))
        inner.append(Spacer(1, 3))
    t = Table([[inner]], colWidths=[168 * mm])
    t.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), bg),
        ("LEFTPADDING", (0, 0), (-1, -1), 11),
        ("RIGHTPADDING", (0, 0), (-1, -1), 11),
        ("TOPPADDING", (0, 0), (-1, -1), 9),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 7),
        ("LINEBEFORE", (0, 0), (0, -1), 2.5, fg),
    ]))
    return t

def rule(space_before=2, space_after=8):
    return HRFlowable(width="100%", thickness=0.6, color=RULE,
                      spaceBefore=space_before, spaceAfter=space_after)

# ── page furniture ──────────────────────────────────────────────────────
def decorate(canvas, doc):
    canvas.saveState()
    canvas.setFont("Sans", 7.5)
    canvas.setFillColor(MUTED)
    canvas.drawString(21 * mm, 12 * mm,
                      "Gamification Module — Scope of Work & Proposal")
    canvas.drawRightString(A4[0] - 21 * mm, 12 * mm, "Page %d" % doc.page)
    canvas.setStrokeColor(RULE)
    canvas.setLineWidth(0.5)
    canvas.line(21 * mm, 16 * mm, A4[0] - 21 * mm, 16 * mm)
    canvas.restoreState()

doc = SimpleDocTemplate(
    "/home/user/Rishi_app2/docs/proposals/gamification-scope-of-work.pdf",
    pagesize=A4, leftMargin=21 * mm, rightMargin=21 * mm,
    topMargin=20 * mm, bottomMargin=20 * mm,
    title="Gamification Module — Scope of Work & Proposal",
    author="Know Thyself — Development",
    subject="Scope of work, constraints and quotation for the gamification module",
)

F = []
W = 168 * mm

# ── header ──────────────────────────────────────────────────────────────
F.append(Paragraph("Gamification Module", st["title"]))
F.append(Paragraph("Scope of Work, Constraints &amp; Quotation", st["sub"]))
F.append(Spacer(1, 9))
meta = Table([[
    Paragraph("<b>Project</b><br/>Know Thyself — mobile app, admin &amp; storefront", st["cell"]),
    Paragraph("<b>Prepared for</b><br/>Anurag Rishi", st["cell"]),
    Paragraph("<b>Document</b><br/>v1.0 — proposal, valid 30 days", st["cell"]),
]], colWidths=[W * 0.42, W * 0.28, W * 0.30])
meta.setStyle(TableStyle([
    ("BACKGROUND", (0, 0), (-1, -1), BAND),
    ("VALIGN", (0, 0), (-1, -1), "TOP"),
    ("TOPPADDING", (0, 0), (-1, -1), 9),
    ("BOTTOMPADDING", (0, 0), (-1, -1), 9),
    ("LEFTPADDING", (0, 0), (-1, -1), 10),
]))
F.append(meta)

# ── 1. summary ──────────────────────────────────────────────────────────
F.append(Paragraph("1. Summary", st["h1"]))
F.append(Paragraph(
    "This proposal covers the addition of a points, rewards and leaderboard system to the "
    "Know Thyself platform. Users earn points for completing meditations and course "
    "episodes; points can be redeemed as a discount against future purchases; a leaderboard "
    "ranks users against one another.", st["body"]))
F.append(Paragraph(
    "The feature is technically achievable on all three surfaces — iOS app, Android app and "
    "web storefront. One part of it, the redemption of points for money off, is subject to an "
    "Apple App Store restriction that materially changes how it behaves on iPhone. That "
    "restriction is set out in section 3 and is not negotiable by either party.", st["body"]))
F.append(Paragraph(
    "This is new work, outside the scope of the existing engagement.", st["body"]))

# ── 2. scope ────────────────────────────────────────────────────────────
F.append(Paragraph("2. Scope of work", st["h1"]))
F.append(Paragraph(
    "Delivered in three phases. Each phase is independently useful and independently "
    "billable, so the project can be stopped or re-scoped at a phase boundary without "
    "leaving a half-built feature in production.", st["body"]))
F.append(Spacer(1, 4))

F.append(Paragraph("Phase 1 — Points engine and display", st["h2"]))
F.append(bullets([
    "Points ledger in the database: one immutable row per earning event, with the rule that produced it.",
    "Server-side awarding only, so points cannot be created or inflated by a modified client.",
    "Idempotent award logic — a retried or duplicated request awards points once, never twice.",
    "Earning rules for: completing a meditation, completing a course episode, completing a full series.",
    "Points balance and history shown in the app, extending the existing Achievements section.",
    "Admin: view any user's balance and ledger, and make a manual adjustment with a reason recorded.",
]))

F.append(Paragraph("Phase 2 — Redemption as discount", st["h2"]))
F.append(bullets([
    "Conversion rule from points to rupees, configurable by the admin rather than fixed in code.",
    "Redemption at web checkout, integrated into the existing coupon and discount pipeline rather than added as a parallel one.",
    "Points deducted only on a confirmed payment, never on an abandoned checkout.",
    "Clawback on refund or revoked access, so a refunded purchase does not leave earned points behind.",
    "Redemption UI on the Android app and the web storefront. <b>Not on iOS</b> — see section 3.",
    "Admin: set and change the conversion rate, and cap the maximum discount per order.",
]))

F.append(Paragraph("Phase 3 — Leaderboard and anti-abuse", st["h2"]))
F.append(bullets([
    "Leaderboard computed as a cached view refreshed on a schedule, not queried live per user.",
    "Opt-in participation, with a display name the user chooses. Nobody appears without consent.",
    "All-time and rolling 30-day boards, so a new user is not permanently behind early adopters.",
    "The anti-abuse measures set out in section 8.",
    "Admin: remove a user from the board, reset a score, and review flagged accounts.",
]))

F.append(Spacer(1, 6))
F.append(table([
    ["Surface", "What changes"],
    ["iOS app", "Earning, balance, achievements, leaderboard. No redemption and no monetary framing."],
    ["Android app", "Everything, including redemption at checkout."],
    ["Web storefront", "Everything, including redemption at checkout."],
    ["Admin dashboard", "Earning rules, conversion rate, balances, manual adjustment, leaderboard moderation."],
    ["Backend", "Ledger, award functions, leaderboard view, clawback on refund."],
], [W * 0.24, W * 0.76]))

# ── 3. iOS constraint ───────────────────────────────────────────────────
F.append(Paragraph("3. The iOS constraint", st["h1"]))
F.append(Paragraph(
    "The iOS app was rebuilt in response to an App Store rejection under Guideline 3.1.1. It now "
    "ships as a “reader” app under Guideline 3.1.3(a): it plays content bought elsewhere and "
    "contains no purchase mechanism of any kind — no prices, no purchase buttons, no checkout, and "
    "no links or prompts pointing at any of those.", st["body"]))
F.append(Paragraph(
    "That exception is all-or-nothing. Telling an iPhone user that their points are worth money off "
    "a purchase is a prompt pointing at an external purchase mechanism, and would put the app back "
    "in breach of the guideline it was rebuilt to satisfy.", st["body"]))
F.append(Spacer(1, 4))
F.append(callout("What this means in practice", [
    "On iPhone, points are points: a number, a streak, a rank. No rupee value is shown, nothing says "
    "“redeem”, and nothing indicates the points are worth anything.",
    "An iPhone user discovers the reward value only when they reach the website. Android and web "
    "users see it in place.",
    "This is Apple’s restriction, not a design choice and not a limitation of the implementation. "
    "The alternative — adding Apple In-App Purchase — is a different project with a different price, "
    "and carries a 15% commission on every transaction.",
]))

# ── 4. not included ─────────────────────────────────────────────────────
F.append(Paragraph("4. Not included in this scope", st["h1"]))
F.append(bullets([
    "Apple In-App Purchase / StoreKit integration of any kind.",
    "Paid points — buying points with money. That would be a digital purchase and would require In-App Purchase on iOS.",
    "Gifting, transferring or trading points between users.",
    "Badges, avatars, artwork or any new illustration; existing visual assets are reused.",
    "Push notifications specific to gamification (“you are 50 points from the top ten”).",
    "Changes to the App Store or Play Store listing copy, which will need rewriting — see section 6.",
    "Accounting or tax treatment of points as a liability.",
    "Any content, copywriting or rule design; the earning rules are supplied by the client (section 9).",
]))

# ── 5. pros ─────────────────────────────────────────────────────────────
F.append(Paragraph("5. Benefits", st["h1"]))
F.append(bullets([
    "<b>Completion, not just opens.</b> Points reward finishing a meditation or an episode, which is the behaviour that makes someone renew.",
    "<b>A reason to come back that is not a notification.</b> A visible balance and rank works on people who have muted push.",
    "<b>Discounts that cost less than they appear to.</b> A points discount is margin given to somebody already engaged, rather than a blanket price cut.",
    "<b>Built on what exists.</b> Achievements, the coupon system and lesson-completion tracking are already in place; this extends them rather than adding a parallel system.",
    "<b>Usable data.</b> The ledger is a per-user record of what was completed and when — useful for content decisions well beyond the points feature itself.",
]))

# ── 6. cons ─────────────────────────────────────────────────────────────
F.append(Paragraph("6. Trade-offs and risks", st["h1"]))
F.append(bullets([
    "<b>It contradicts the product’s current positioning.</b> The live App Store description states: "
    "“No streaks to protect, no badges demanding attention, nothing flashing for your time.” A "
    "competitive leaderboard is the opposite of that promise, and the listing copy will have to be "
    "rewritten to match.",
    "<b>Competition and meditation pull against each other.</b> Ranking users by output introduces "
    "pressure into a practice whose purpose is to remove it. Calm and Headspace both use streaks and "
    "both avoid public competitive leaderboards. Recommended mitigation: keep the leaderboard opt-in.",
    "<b>Points are a financial liability.</b> Once issued they represent a future discount. Their "
    "treatment on refunds, expiry and account deletion is a business decision with money attached.",
    "<b>An inconsistent experience across platforms.</b> iPhone users see a weaker version of the "
    "feature, for reasons they cannot see.",
    "<b>New abuse surface.</b> Anything that pays out will be gamed. Section 8 covers the mitigations; "
    "none of them is permanent, and this feature will need occasional attention after launch.",
    "<b>Leaderboards expose user identity.</b> Publishing names creates a privacy obligation and a "
    "moderation duty, and will require an update to the store data-safety declarations.",
]))

F.append(Paragraph("7. Outside our control", st["h1"]))
F.append(Paragraph(
    "The following are decided by third parties. They are stated here so that expectations are set "
    "before work begins rather than after.", st["body"]))
F.append(Spacer(1, 3))
F.append(callout("No guarantee of App Store approval", [
    "<b>App Store and Play Store review outcomes cannot be guaranteed by anyone, including us.</b> "
    "Apple applies its guidelines at the discretion of an individual reviewer, changes those "
    "guidelines without notice, and reaches different conclusions on different submissions of the "
    "same app.",
    "The implementation will be built to comply with Guideline 3.1.3(a) as it is written and as it "
    "has been applied to this app to date. That is the most that can be undertaken. It is not a "
    "warranty of acceptance.",
    "If a submission is rejected for reasons arising from this feature, the remediation work will be "
    "quoted and billed separately. It is not covered by this fee.",
    "Apple’s current review of the existing reader-app submission is unresolved. If that submission "
    "is itself rejected, the constraints in section 3 may change, and parts of this scope may need "
    "reworking at additional cost.",
], bg=colors.HexColor("#FBEDED"), fg=colors.HexColor("#9B2C2C")))
F.append(Spacer(1, 5))
F.append(bullets([
    "Changes to Apple or Google policy during or after development.",
    "Razorpay, Supabase, Cloudflare, Bunny or Firebase pricing, limits, outages or policy changes.",
    "Review turnaround times at either store.",
    "Whether users adopt the feature; engagement outcomes are not warranted.",
]))

# ── 8. anti-abuse ───────────────────────────────────────────────────────
F.append(Paragraph("8. Anti-abuse measures", st["h1"]))
F.append(Paragraph(
    "Points convert to money, so they will be attacked. The following are included in Phase 3.", st["body"]))
F.append(Spacer(1, 3))
F.append(table([
    ["Attack", "Mitigation"],
    ["Skipping to the end of a video or audio track to mark it complete",
     "Completion requires accumulated playback time consistent with the item’s duration, measured server-side — not a seek to the end."],
    ["Replaying the same item repeatedly for points",
     "Points are awarded once per user per item, enforced by a unique constraint in the ledger rather than by a client-side check."],
    ["Forging award requests directly against the API",
     "Awards are written only by a server-side function that verifies the caller’s identity from their own session token. No client can write to the ledger."],
    ["Retry or network duplication awarding twice",
     "Every award carries an idempotency key. A repeated request returns the original result and writes nothing."],
    ["Multiple accounts farming points for one person’s discount",
     "Points are non-transferable, and the existing one-account-one-device control already limits parallel use. Suspicious velocity is flagged for admin review."],
    ["Automated or scripted completion at inhuman rates",
     "Per-user rate limits on awards, with a daily ceiling. Breaches are flagged rather than silently dropped, so genuine heavy users can be released by an admin."],
    ["Earning points, redeeming them, then refunding the purchase",
     "Clawback on refund and on revoked access. A balance can go to zero; it is never allowed to go negative silently."],
    ["Manipulating the leaderboard with an offensive display name",
     "Display names are user-set but admin-removable, and participation is opt-in."],
], [W * 0.36, W * 0.64]))
F.append(Spacer(1, 5))
F.append(Paragraph(
    "These raise the cost of abuse; they do not end it. Anti-abuse is an ongoing activity, not a "
    "one-time delivery. A maintenance arrangement is recommended and quoted separately.", st["small"]))

# ── 9. client decisions ─────────────────────────────────────────────────
F.append(Paragraph("9. Decisions required before work begins", st["h1"]))
F.append(Paragraph(
    "These are business rules, not technical choices. Development cannot start on the phase "
    "concerned until each is confirmed in writing.", st["body"]))
F.append(Spacer(1, 3))
F.append(table([
    ["Decision", "Needed for"],
    ["Points awarded per meditation, per episode, per completed series", "Phase 1"],
    ["Conversion rate — how many points equal one rupee of discount", "Phase 2"],
    ["Maximum discount permitted on a single order", "Phase 2"],
    ["Whether points expire, and after how long", "Phase 2"],
    ["What happens to points on refund, and on account deletion", "Phase 2"],
    ["Whether the leaderboard is opt-in (recommended) or opt-out", "Phase 3"],
], [W * 0.62, W * 0.38]))
F.append(Spacer(1, 5))
F.append(Paragraph(
    "The refund and expiry rules have money attached and are worth confirming with the client’s "
    "accountant before they are built.", st["small"]))

# ── 10. timeline ────────────────────────────────────────────────────────
F.append(Paragraph("10. Timeline", st["h1"]))
F.append(table([
    ["Phase", "Working days", "Depends on"],
    ["Phase 1 — Points engine and display", "5 – 7", "Earning rules confirmed"],
    ["Phase 2 — Redemption as discount", "4 – 6", "Phase 1 delivered; conversion and refund rules confirmed"],
    ["Phase 3 — Leaderboard and anti-abuse", "5 – 8", "Phase 1 delivered"],
    ["<b>Total</b>", "<b>14 – 21</b>", ""],
], [W * 0.42, W * 0.18, W * 0.40]))
F.append(Spacer(1, 5))
F.append(Paragraph(
    "Working days, excluding client review time, store review time, and any wait on the decisions "
    "listed in section 9. Store review is outside our control and is not included in any estimate.",
    st["small"]))

# ── 11. commercials ─────────────────────────────────────────────────────
F.append(Paragraph("11. Quotation", st["h1"]))
F.append(table([
    ["Phase", "Fee"],
    ["Phase 1 — Points engine, server-side awarding, in-app display, admin controls", "₹18,000"],
    ["Phase 2 — Redemption at checkout, conversion rules, clawback on refund", "₹14,000"],
    ["Phase 3 — Leaderboard, opt-in, moderation, anti-abuse measures", "₹18,000"],
], [W * 0.76, W * 0.24]))
total = Table([[Paragraph("Total — fixed fee for the scope set out in this document", st["cellb"]),
                Paragraph("<b>₹50,000</b>", ParagraphStyle("tot", fontName="Sans-B", fontSize=12,
                                                           leading=15, textColor=SAGE))]],
              colWidths=[W * 0.76, W * 0.24])
total.setStyle(TableStyle([
    ("BACKGROUND", (0, 0), (-1, -1), BAND),
    ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
    ("TOPPADDING", (0, 0), (-1, -1), 10),
    ("BOTTOMPADDING", (0, 0), (-1, -1), 10),
    ("LEFTPADDING", (0, 0), (-1, -1), 8),
    ("RIGHTPADDING", (0, 0), (-1, -1), 8),
    ("LINEABOVE", (0, 0), (-1, 0), 1.2, SAGE),
]))
F.append(total)
F.append(Spacer(1, 8))

F.append(Paragraph("Payment schedule", st["h2"]))
F.append(table([
    ["Milestone", "Amount"],
    ["On acceptance of this proposal", "₹20,000 (40%)"],
    ["On delivery of Phase 2", "₹15,000 (30%)"],
    ["On delivery of Phase 3", "₹15,000 (30%)"],
], [W * 0.76, W * 0.24]))
F.append(Spacer(1, 8))

F.append(Paragraph("Billable separately", st["h2"]))
F.append(bullets([
    "Remediation of any App Store or Play Store rejection arising from this feature (section 7).",
    "Any Apple In-App Purchase work, should the client decide to adopt it.",
    "Changes to earning or conversion rules after the phase concerned has been delivered.",
    "Store listing copy rewrites, screenshots and marketing assets.",
    "Ongoing anti-abuse monitoring and response after delivery.",
    "Anything listed in section 4.",
]))
F.append(Spacer(1, 4))
F.append(Paragraph(
    "Third-party running costs are the client’s and are not included. This feature is expected to add "
    "little: a Supabase Pro plan is already recommended for this platform independently of it, and the "
    "additional load from points and the leaderboard is not expected to exceed roughly ₹0 – 3,500 per "
    "month at current user numbers.", st["small"]))

# ── 12. terms ───────────────────────────────────────────────────────────
F.append(Paragraph("12. Terms", st["h1"]))
F.append(bullets([
    "Fixed fee for the scope set out in this document. Work outside it is quoted before it is started.",
    "This proposal is valid for 30 days from the date of issue.",
    "The estimate assumes continued access to the existing Supabase, Vercel, Codemagic, Razorpay and Apple Developer accounts.",
    "Delivery is to the existing repository and deployment pipeline. Store submission remains the client’s responsibility and decision.",
    "Defects in the delivered scope are corrected at no charge for 30 days after each phase is delivered. Store rejections are not defects.",
]))
accept_block = [
    Paragraph("13. Acceptance", st["h1"]),
    Paragraph(
        "Signing below confirms acceptance of the scope, constraints and fee set out in this "
        "document, including section 7 — that no party can guarantee the outcome of an App "
        "Store or Play Store review, and that remediation of a rejection is billed separately.",
        st["body"]),
    Spacer(1, 10),
    rule(0, 10),
]
sign = Table([[
    Paragraph("<b>Accepted for the client</b><br/><br/><br/>"
              "______________________________<br/>Name<br/><br/>"
              "______________________________<br/>Date", st["cell"]),
    Paragraph("<b>For the developer</b><br/><br/><br/>"
              "______________________________<br/>Name<br/><br/>"
              "______________________________<br/>Date", st["cell"]),
]], colWidths=[W / 2, W / 2])
sign.setStyle(TableStyle([("VALIGN", (0, 0), (-1, -1), "TOP"),
                          ("LEFTPADDING", (0, 0), (-1, -1), 0),
                          ("TOPPADDING", (0, 0), (-1, -1), 4)]))
# Heading, preamble and signature lines travel as one unit — a heading
# stranded at the foot of one page with its signature block on the next
# reads as a document that was assembled carelessly.
accept_block.append(sign)
F.append(KeepTogether(accept_block))

doc.build(F, onFirstPage=decorate, onLaterPages=decorate)
print("built")
