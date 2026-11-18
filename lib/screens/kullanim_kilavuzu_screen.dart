
import 'package:flutter/material.dart';

class KullanimKilavuzuScreen extends StatelessWidget {
  const KullanimKilavuzuScreen({super.key});

  Widget _buildSection({
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              content,
              style: const TextStyle(
                fontSize: 14,
                height: 1.6,
              ),
              textAlign: TextAlign.start,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kullanım Kılavuzu'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection(
            icon: Icons.home_outlined,
            title: 'Anasayfa',
            content:
            'Bazen GİB (Gelir İdaresi Başkanlığı) tarafında bağlantı '
                'sorunları yaşanabilir. Bu durumda sağ üstteki çıkış butonuyla '
                'çıkış yapıp tekrar giriş yapmayı deneyin.\n\n'
                'Tekrar giriş yapmak işe yaramazsa GİB sisteminin özellikle '
                'mesai saatleri dışında bakım gibi nedenlerle kapalı olabileceğini '
                'unutmayın. Böyle durumlarda e-Arşiv web portalına da giriş '
                'yapılamayabilir.\n\n'
                'Yalnızca tarih aralığı seçildiğinde, o tarih aralığında bu '
                'uygulamaya kayıtlı faturalar listelenir. Tarih seçildikten '
                'sonra "GİB\'den Çek" butonuyla, uygulama üzerinden '
                'kesilmeyen faturalar da dahil olmak üzere e-Arşiv '
                'portalındaki faturalar getirilebilir.\n\n'
                'Uygulama üzerinden kesilen faturalarda unvan, adres, tutar '
                'gibi tüm fatura bilgileri ve faturanın gerçek görüntüsü '
                'yer alır. GİB\'den getirilen, ancak bu uygulama üzerinden '
                'kesilmeyen faturalarda ise yalnızca unvan ve VKN/TCKN '
                'bilgileri gösterilir; tutar 0 TL görünür. Bunun nedeni, '
                'GİB\'in fatura içeriğini uygulamaya ayrıntılı olarak '
                'aktarmamasıdır.\n\n'
                'Her iki durumda da "GİB\'de Görüntüle" veya "PDF Paylaş" '
                'butonlarıyla açılan PDF dosyaları faturanın gerçek '
                'görüntüsüdür. Faturalarınızı buradan görüntüleyebilir '
                've PDF olarak paylaşabilirsiniz.',
          ),
          _buildSection(
            icon: Icons.receipt_long_outlined,
            title: 'Yeni Fatura',
            content:
            'Bu bölümde vergi numarası veya T.C. kimlik numarası '
                'girildiğinde, müşteri daha önce kayıt edilmişse bilgileri '
                'otomatik olarak doldurulur.\n\n'
                'Müşteri kayıtlı değilse girilen numara GİB üzerinden '
                'sorgulanır. Şahıs müşterilerde ad, soyad ve vergi dairesi, şirketlerde '
                'ise unvan ve vergi dairesi bilgileri otomatik doldurulur. '
                'Adres bilgisini bir kez sizin girmeniz yeterlidir.\n\n'
                'Ardından fatura kesilecek mal veya hizmet bilgilerini '
                'doldurabilirsiniz. Birden fazla kalem eklemek için '
                '"Kalem Ekle" butonunu kullanabilirsiniz. En alttaki not '
                'bölümüne IBAN veya başka bir açıklama ekleyebilirsiniz.\n\n'
                '"Fatura Oluştur" butonuna bastığınızda açılan pencereden '
                '"İmzala" seçeneğiyle SMS üzerinden fatura imzalama '
                'işlemine geçebilir veya "Daha Sonra" seçeneğiyle '
                'imzalamayı erteleyebilirsiniz.\n\n'
                'Kesilen faturalar, Faturalar bölümünden açılarak '
                '"GİB\'de Görüntüle" ve "PDF Paylaş" butonlarıyla '
                'görüntülenebilir ve paylaşılabilir. Faturayı henüz '
                'imzalamadıysanız, kontrol ettikten sonra "SMS ile İmzala" '
                'butonuyla imzalayabilirsiniz.\n\n'
                'İmzalama işleminden sonra fatura görüntüsündeki '
                'imzasız olduğuna dair uyarı kalkar. İmzalandığı halde '
                'eski görüntüde bu uyarı görünmeye devam ederse, '
                'anasayfadaki "GİB\'den Çek" butonuyla faturaları '
                'yenileyebilirsiniz.',
          ),
          _buildSection(
            icon: Icons.people_outline,
            title: 'Müşteriler',
            content:
            'Bu bölümde daha önce fatura kesilmiş müşteriler '
                'listelenir. Müşterilerin yanındaki butona basıldığında '
                'açılan menüden "Fatura Kes" butonu ile ilgili müşterinin bilgileri doğrudan '
                'fatura kesme ekranına aktarılabilir.\n\n'
                'GİB\'den gelen ancak adres bilgisi bulunmayan müşterilerin '
                'adresleri de bu bölümden düzenlenebilir ve eklenebilir.\n\n'
                'Üstteki arama alanına kayıtlı olmayan bir isim, unvan, '
                'VKN veya TCKN yazıldığında çıkan "Müşteri Ekle" butonuyla '
                'yeni müşteri kaydı oluşturabilirsiniz.',
          ),
        ],
      ),
    );
  }
}
