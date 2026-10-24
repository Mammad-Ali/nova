import 'learn_content.dart';

/// Azerbaijani text of the Learn, About and Help pages.
const learnAz = LearnContent(
  glossary: [
    Article(
      'Yükləmə',
      'Məlumatların sizə nə qədər sürətlə çatdığı: səhifələr, video, fayllar. Saniyədə meqabitlə (Mbps) ölçülür.',
    ),
    Article(
      'Göndərmə',
      'Məlumatları nə qədər sürətlə göndərdiyiniz: video zənglər, bulud ehtiyat nüsxələri, foto və faylların yüklənməsi.',
    ),
    Article(
      'Ping',
      'Kiçik bir mesajın serverə çatıb geri qayıtması üçün lazım olan vaxt, millisaniyə ilə. Nə qədər az olsa, oyunlar və zənglər bir o qədər cəld olur.',
    ),
    Article(
      'Jitter',
      'Pingin an-an nə qədər dəyişdiyi. Yüksək jitter orta ping yaxşı olsa belə zəngləri qırıq-qırıq edir.',
    ),
    Article(
      'Yük altında gecikmə',
      'Kanal məşğul olanda pingin nə qədər artdığı. Böyük artım — «bufferbloat» — kimsə yükləməyə başlayan kimi oyunun donmasının səbəbidir.',
    ),
    Article(
      'Mbps',
      'Saniyədə meqabit. Səkkiz meqabit bir meqabayt edir, yəni 100 Mbps saniyədə təxminən 12,5 meqabayt ötürür.',
    ),
    Article(
      'Paket itkisi',
      'Heç vaxt çatmayan məlumat paketlərinin payı. Hətta 1–2% zənglərdə və oyunlarda kəsilmələrə səbəb olur.',
    ),
    Article(
      'Provayder',
      'Sizi internetə qoşan şirkət.',
    ),
    Article(
      'Məhdudlaşdırma',
      'Provayderin müəyyən trafiki, məsələn videonu, qəsdən yavaşlatması — qalan hər şey isə sürətli qalır.',
    ),
  ],
  guides: [
    Article(
      'Dəqiq nəticə almaq',
      'Evdəki bütün cihazlarda yükləmələri və yayımları dayandırın, mümkünsə kabeldən istifadə edin və ya routerə yaxın oturun, sonra testi iki-üç dəfə edin. Tipik nəticə təsadüfi uğurlu nəticədən daha çox şey deyir.',
    ),
    Article(
      'Wi-Fi, yoxsa xətt?',
      'Eyni yerdə bir dəfə kabellə, bir dəfə Wi-Fi ilə test edin. Kabel xeyli sürətlidirsə, dar boğaz simsiz əlaqədədir: routerə yaxınlaşın, 5 GHz şəbəkəsinə keçin və ya siqnalı Nova tətbiqində yoxlayın.',
    ),
    Article(
      'Mənə nə qədər sürət lazımdır?',
      'Veb və sosial şəbəkələr üçün təxminən 5 Mbps, HD video üçün 5–8, 4K üçün 25, video zəng üçün hər istiqamətdə 3–4 kifayətdir. Onlayn oyunlar üçün ping sürətdən daha vacibdir — 50 ms-dən aşağı rahatdır. Evdə ehtiyaclar toplanır: eyni anda video baxan üç nəfərə üç qat çox lazımdır.',
    ),
    Article(
      'Yük altında gecikmə qiymətini oxumaq',
      'A və ya B: bağlantı məşğul olanda da cəld qalır. C və ya D: kimsə nəsə yükləyəndə gecikmə sıçrayır. Routerin tənzimləmələrində «SQM» və ya «Smart Queue» funksiyasını yandırmaq çox vaxt kömək edir.',
    ),
  ],
  faq: [
    Article(
      'Nəticə niyə tarifdəkindən aşağıdır?',
      'Tarifdə maksimum göstərilir. Wi-Fi, digər cihazlar, serverə məsafə və axşam yüklənməsi öz payını götürür. Kabellə test xəttin özünün nə verdiyini göstərir.',
    ),
    Article(
      'Fərqli sürət testləri niyə fərqli rəqəmlər göstərir?',
      'Hər biri öz serverlərindən və metodundan istifadə edir. Nova Cloudflare-ə qədər dörd paralel bağlantı ilə ölçür — bu, böyük yükləmələrin davranışına yaxındır.',
    ),
    Article(
      'Test nə qədər trafik sərf edir?',
      'Təxminən sürət vurulsun on altı saniyə: 100 Mbps xəttdə təxminən 200 MB, daha sürətli xətlərdə daha çox. Mobil internetdə bunu nəzərə alın.',
    ),
    Article(
      'Nəticələrim harasa göndərilir?',
      'Xeyr. Tarixçə və tənzimləmələr cihazınızda qalır. «Məxfilik» səhifəsində Nova-nın kimlə əlaqə saxladığı dəqiq sadalanır.',
    ),
    Article(
      'Brauzer versiyası niyə daha az bacarır?',
      'Brauzer sistem trafik sayğaclarını oxuya, lokal şəbəkəni skan edə və Wi-Fi məlumatlarını görə bilmir. Tətbiq isə Windows, macOS və Android-də bunu bacarır.',
    ),
    Article(
      'Nova pulsuzdur?',
      'Bəli, tamamilə. Nova MIT lisenziyası ilə açıq mənbəlidir.',
    ),
  ],
  about: 'Nova pulsuz, açıq mənbəli şəbəkə köməkçisidir: bir tətbiqdə dəqiq sürət testi və canlı trafik monitoru. Sırf sürətdən əlavə, bağlantının necə hiss olunduğunu müəyyən edən göstəriciləri ölçür — yük altında gecikmə, jitter və sabitlik. Windows, macOS və Android-də işləyir, sürət testi isə birbaşa brauzerdə də işləyir.',
  privacy: [
    Article(
      'Cihazınızda qalır',
      'Test nəticələri, tarixçə, tənzimləmələr və trafik statistikası yalnız cihazınızda saxlanılır. Nova-nın onları toplayan öz serveri yoxdur.',
    ),
    Article(
      'Nova kimlə əlaqə saxlayır',
      'Sürət testi Cloudflare-in sürət testi serverləri ilə məlumat mübadiləsi edir. Provayderi və şəhəri göstərmək üçün Nova ipwho.is xidmətinə müraciət edir, o da IP ünvanınızı görür. Məhdudlaşdırma yoxlaması Netflix-in fast.com xidmətindən istifadə edir, servislərə ping isə YouTube, Google, Discord, Steam, Cloudflare və Telegram ilə əlaqə saxlayır. Şəbəkə skanı yalnız lokal şəbəkənizdəki cihazlarla əlaqə saxlayır. Brauzer versiyası GitHub Pages-də yerləşir və qrafik mühərrikini Google-un gstatic.com saytından yükləyir.',
    ),
    Article(
      'Reytinq',
      'Hələlik tətbiqin daxilində nümunə məlumatlarla işləyir və heç nə dərc olunmur. Onlayn reytinq işə düşəndə yalnız ləqəbiniz, ölkəniz, provayderiniz və ən yaxşı nəticəniz paylaşılacaq — adınız və e-poçtunuz heç vaxt.',
    ),
    Article(
      'İzləmə yoxdur',
      'Nə reklam, nə analitika, nə də izləyicilər.',
    ),
  ],
  help: [
    Article(
      'Testi başlatmaq',
      '«Testə başla» düyməsini basın. Nova əvvəlcə pingi, sonra yükləmə və göndərməni ölçür — cəmi təxminən iyirmi saniyə.',
    ),
    Article(
      'Test alınmır',
      'Bağlantını yoxlayın və yenidən cəhd edin. Cloudflare-i bloklayan VPN və ya firewall testin serverə çatmasına mane olur.',
    ),
    Article(
      'İlk açılışda xəbərdarlıq',
      'Nova ödənişli Apple və ya Microsoft sertifikatı ilə deyil, öz açarı ilə imzalanıb. Windows: «Ətraflı» → «Hər halda işə sal». macOS: Sistem tənzimləmələri → Məxfilik və təhlükəsizlik → «Hər halda aç». Android: «Hər halda quraşdır».',
    ),
    Article(
      'Nəsə düz işləmir',
      'GitHub-da bildirin — aşağıdakı düymə müraciətlər səhifəsini açır.',
    ),
  ],
  reportButton: 'Problemi bildir',
);
